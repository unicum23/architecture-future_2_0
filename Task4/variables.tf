variable "cloud_id" {
  description = "Идентификатор облака в Yandex Cloud"
  type        = string
}

variable "folder_id" {
  description = "Идентификатор каталога (folder), в котором создаются ресурсы"
  type        = string
}

variable "zone" {
  description = "Зона доступности (например ru-central1-a)"
  type        = string
  default     = "ru-central1-a"
}

variable "environment" {
  description = "Метка окружения для тегирования ресурсов"
  type        = string
  default     = "dev"
}

variable "admin_cidr" {
  description = "CIDR сети, с которой разрешён SSH на bastion (например ваш публичный IP/32)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ для пользователя ubuntu на ВМ"
  type        = string
}

variable "bastion_resources" {
  description = "Размер bastion ВМ (минимальная конфигурация для доступа)"
  type = object({
    cores     = number
    memory    = number
    disk_size = number
  })
  default = {
    cores     = 2
    memory    = 2
    disk_size = 10
  }
}

variable "app_resources" {
  description = "Размер прикладной ВМ и загрузочного диска"
  type = object({
    cores     = number
    memory    = number
    disk_size = number
  })
  default = {
    cores     = 4
    memory    = 8
    disk_size = 20
  }
}

variable "data_disk_size" {
  description = "Размер дополнительного диска данных (ГИБ), network-hdd"
  type        = number
  default     = 50
}

variable "image_family" {
  description = "Семейство образа ОС для загрузочных дисков"
  type        = string
  default     = "ubuntu-2204-lts"
}
