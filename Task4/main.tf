terraform {
  required_version = ">= 1.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.130"
    }
  }
}

# Токен в блоке provider не задаём — провайдер читает переменную окружения YC_TOKEN.
# Перед plan/apply: export YC_TOKEN=$(yc iam create-token)
provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

locals {
  labels = {
    project     = "future20"
    environment = var.environment
    managed_by  = "terraform"
  }
}

data "yandex_compute_image" "ubuntu" {
  family = var.image_family
}

# ---------------------------------------------------------------------------
# Сеть: VPC, публичная и приватная подсети, NAT-шлюз и маршрутизация
# ---------------------------------------------------------------------------

resource "yandex_vpc_network" "main" {
  name        = "future20-vpc"
  description = "Корпоративная сеть для пилота IaaS"
  labels      = local.labels
}

resource "yandex_vpc_subnet" "public" {
  name           = "future20-public"
  description    = "Публичная подсеть (bastion, внешний доступ)"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.10.0.0/24"]
  zone           = var.zone
  labels         = local.labels
}

resource "yandex_vpc_gateway" "nat" {
  name = "future20-nat-gateway"
  shared_egress_gateway {}
  labels = local.labels
}

resource "yandex_vpc_route_table" "private_rt" {
  name       = "future20-private-rt"
  network_id = yandex_vpc_network.main.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }

  labels = local.labels
}

resource "yandex_vpc_subnet" "private" {
  name           = "future20-private"
  description    = "Приватная подсеть: приложение без публичного IP, исходящий интернет через NAT"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.10.1.0/24"]
  zone           = var.zone
  route_table_id = yandex_vpc_route_table.private_rt.id
  labels         = local.labels
}

# ---------------------------------------------------------------------------
# Группы безопасности
# ---------------------------------------------------------------------------

resource "yandex_vpc_security_group" "bastion" {
  name        = "future20-bastion-sg"
  description = "SSH с внешней сети только на bastion"
  network_id  = yandex_vpc_network.main.id
  labels      = local.labels

  ingress {
    protocol       = "TCP"
    description    = "SSH из админской сети"
    port           = 22
    v4_cidr_blocks = [var.admin_cidr]
  }

  egress {
    protocol       = "ANY"
    description    = "Исходящий трафик"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "app" {
  name        = "future20-app-sg"
  description = "Прикладная ВМ: SSH только из публичной подсети (bastion)"
  network_id  = yandex_vpc_network.main.id
  labels      = local.labels

  ingress {
    protocol       = "TCP"
    description    = "SSH с bastion"
    port           = 22
    v4_cidr_blocks = [yandex_vpc_subnet.public.v4_cidr_blocks[0]]
  }

  egress {
    protocol       = "ANY"
    description    = "Исходящий трафик (через NAT)"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------
# Диск данных (отдельный ресурс — явно управляется Terraform)
# ---------------------------------------------------------------------------

resource "yandex_compute_disk" "app_data" {
  name = "future20-app-data"
  type = "network-hdd"
  size = var.data_disk_size
  zone = var.zone

  labels = local.labels
}

# ---------------------------------------------------------------------------
# Виртуальные машины: bastion (публичная сеть + NAT на ВМ) и app (приватная)
# ---------------------------------------------------------------------------

resource "yandex_compute_instance" "bastion" {
  name        = "future20-bastion"
  hostname    = "bastion"
  platform_id = "standard-v3"
  zone        = var.zone
  labels      = local.labels

  resources {
    cores         = var.bastion_resources.cores
    memory        = var.bastion_resources.memory
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.bastion_resources.disk_size
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

resource "yandex_compute_instance" "app" {
  name        = "future20-app"
  hostname    = "app"
  platform_id = "standard-v3"
  zone        = var.zone
  labels      = local.labels

  resources {
    cores         = var.app_resources.cores
    memory        = var.app_resources.memory
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.app_resources.disk_size
      type     = "network-ssd"
    }
  }

  secondary_disk {
    disk_id = yandex_compute_disk.app_data.id
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.app.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  depends_on = [
    yandex_compute_instance.bastion
  ]
}
