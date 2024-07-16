variable "location" {
  type        = string
  description = "Región por defecto de los recursos"
  default     = "West Europe"
}

variable "resourceGroupName" {
  type        = string
  description = "Nombre por defecto del grupo de recursos"
  default     = "UNIR"
}

variable "sku" {
  type        = string
  description = "Recursos de la máquina virtual"
  default     = "Standard_D1_v2"
}

variable "aks-sku" {
  type        = string
  description = "Recursos del clúster AKS"
  default     = "Standard_A2_v2"
}

variable "suscriptionId" {
  type        = string
  description = "Id de la suscripción"
}

variable "tenantId" {
  type        = string
  description = "Id del Tenant"
}

variable "adminUsername" {
  type        = string
  description = "Usuario administrador de la máquina virtual"
}