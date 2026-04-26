output "vpc_id" {
  description = "Идентификатор созданной VPC"
  value       = yandex_vpc_network.main.id
}

output "subnet_public_id" {
  description = "Публичная подсеть (bastion)"
  value       = yandex_vpc_subnet.public.id
}

output "subnet_private_id" {
  description = "Приватная подсеть (приложение)"
  value       = yandex_vpc_subnet.private.id
}

output "nat_gateway_id" {
  description = "NAT-шлюз для исходящего трафика из приватной подсети"
  value       = yandex_vpc_gateway.nat.id
}

output "route_table_id" {
  description = "Таблица маршрутизации с default через NAT"
  value       = yandex_vpc_route_table.private_rt.id
}

output "bastion_public_ip" {
  description = "Публичный IP bastion (SSH через него к приложению)"
  value       = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
}

output "bastion_internal_ip" {
  description = "Внутренний IP bastion"
  value       = yandex_compute_instance.bastion.network_interface[0].ip_address
}

output "app_private_ip" {
  description = "Внутренний IP прикладной ВМ в приватной подсети"
  value       = yandex_compute_instance.app.network_interface[0].ip_address
}

output "data_disk_id" {
  description = "Идентификатор диска данных"
  value       = yandex_compute_disk.app_data.id
}

output "ssh_hint" {
  description = "Подсказка по подключению"
  value       = "ssh ubuntu@${yandex_compute_instance.bastion.network_interface[0].nat_ip_address} затем ssh ubuntu@${yandex_compute_instance.app.network_interface[0].ip_address}"
}
