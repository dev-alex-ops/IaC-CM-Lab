# Grupo de recursos general
resource "azurerm_resource_group" "tf-rg" {
  name     = var.resourceGroupName
  location = var.location

  tags = {
    source = "terraform"
  }
}

# Red virtual general
resource "azurerm_virtual_network" "tf-vnet" {
  name                = "vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.tf-rg.location
  resource_group_name = azurerm_resource_group.tf-rg.name

  tags = {
    source = "terraform"
  }
}

# Subred para la máquina virtual
resource "azurerm_subnet" "tf-subnet-vm" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.tf-rg.name
  virtual_network_name = azurerm_virtual_network.tf-vnet.name
  address_prefixes     = ["10.0.2.0/24"]

}

# Security group con las reglas de acceso para la máquina virtual
resource "azurerm_network_security_group" "tf-sg" {
  name                = "vm-sg"
  location            = azurerm_resource_group.tf-rg.location
  resource_group_name = azurerm_resource_group.tf-rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP2"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    source = "terraform"
  }
}

# IP pública para asignar a la máquina virtual
resource "azurerm_public_ip" "tf-pip" {
  name                = "public-ip"
  location            = azurerm_resource_group.tf-rg.location
  resource_group_name = azurerm_resource_group.tf-rg.name
  allocation_method   = "Dynamic"

  tags = {
    source = "terraform"
  }
}

# Interfaz de red para la máquina virtual con la configuración para que se incluya en la subnet y se asigne la IP pública
resource "azurerm_network_interface" "tf-nic" {
  name                = "vm-nic"
  location            = azurerm_resource_group.tf-rg.location
  resource_group_name = azurerm_resource_group.tf-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tf-subnet-vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tf-pip.id
  }
}

# Asociación de la interfaz de red a las posíticas del grupo de seguridad
resource "azurerm_network_interface_security_group_association" "tf-nic-sg" {
  network_interface_id      = azurerm_network_interface.tf-nic.id
  network_security_group_id = azurerm_network_security_group.tf-sg.id
}

# Clave SSH gestionada por Azure
resource "tls_private_key" "tf-ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Máquina virtual con la configuración de red, pares ssh (del equipo que lo lanza), imágen y discos 
resource "azurerm_linux_virtual_machine" "tf-vm" {
  name                = "vm-webapp"
  resource_group_name = azurerm_resource_group.tf-rg.name
  location            = azurerm_resource_group.tf-rg.location
  size                = var.sku
  admin_username      = var.adminUsername
  network_interface_ids = [
    azurerm_network_interface.tf-nic.id,
  ]

  admin_ssh_key {
    username   = var.adminUsername
    public_key = tls_private_key.tf-ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    source = "terraform"
  }
}

# Azure Container Registry
resource "azurerm_container_registry" "tf-acr" {
  name                = "devalexhub"
  resource_group_name = azurerm_resource_group.tf-rg.name
  location            = azurerm_resource_group.tf-rg.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = {
    source : "Terraform"
  }
}

# Clúster de Azure AKS
resource "azurerm_kubernetes_cluster" "tf-aks" {
  name                = "cluster-aks"
  location            = azurerm_resource_group.tf-rg.location
  resource_group_name = azurerm_resource_group.tf-rg.name
  dns_prefix          = "dnsaks"
  sku_tier            = "Standard"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = var.aks-sku
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    source = "Terraform"
  }
}

# Permisos de ACRPull para el clúster de Kubernetes de AKS
resource "azurerm_role_assignment" "tf-perm" {
  principal_id         = azurerm_kubernetes_cluster.tf-aks.identity[0].principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.tf-acr.id
}