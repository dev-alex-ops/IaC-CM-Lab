output "vm_public_ip" {
  description = "Ip pública de acceso a la máquina virtual"
  value       = azurerm_linux_virtual_machine.tf-vm.public_ip_address
}

output "kube_config" {
  description = "Fichero de configuración raw de kubectl"
  value       = azurerm_kubernetes_cluster.tf-aks.kube_config_raw
  sensitive   = true
}

output "acr_login_url" {
  description = "URL de login al ACR"
  value       = azurerm_container_registry.tf-acr.login_server
  sensitive   = true
}

output "acr_username" {
  description = "Usuario de acceso a ACR"
  value       = azurerm_container_registry.tf-acr.admin_username
  sensitive   = true
}

output "acr_password" {
  description = "Contraseña de acceso a ACR"
  value       = azurerm_container_registry.tf-acr.admin_password
  sensitive   = true
}

output "ssh_private_key_file" {
  description = "Clave pública del SSH generada por Azure"
  value       = tls_private_key.tf-ssh.private_key_openssh
  sensitive   = true
}

output "vm_admin_username" {
  description = "Usuario de acceso a la máquina virtual"
  value = azurerm_linux_virtual_machine.tf-vm.admin_username
  sensitive = true
}