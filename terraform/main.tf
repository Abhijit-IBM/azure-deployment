provider "azurerm" {
    features {}
    skip_provider_registration = true

    # subscription_id   = ${env.ARM_SUBSCRIPTION_ID}
    # tenant_id         = ${env.ARM_TENANT_ID}
    # client_id         = ${env.ARM_CLIENT_ID}
    # client_secret     = ${env.ARM_CLIENT_ID}
}

resource "azurerm_resource_group" "rg" {
    name = "${var.prefix}-resource-group"
    location = "${var.region}"
}

resource "random_id" "this" {
    byte_length = 2
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "ssh_rdp" {
  name                = "${var.prefix}-nsg-${random_id.this.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow_ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = 22
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow_RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = 3389
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "vpc" {
    name = "${var.prefix}-vpn"
    location = "${var.region}"
    resource_group_name = azurerm_resource_group.rg.name
    address_space = var.vpc_address_space
}

resource "azurerm_subnet" "subnet1" {
    name = "${var.prefix}-subnet-1"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vpc.name
    address_prefixes = var.subnet_address_space
}

resource "azurerm_subnet_network_security_group_association" "this" {
    subnet_id = azurerm_subnet.subnet1.id
    network_security_group_id = azurerm_network_security_group.ssh_rdp.id
}


resource "azurerm_network_interface" "nic" {
    name = "${var.prefix}-nic"
    location = var.region
    resource_group_name = azurerm_resource_group.rg.name
    ip_configuration {
        name = "configuration1"
        subnet_id = azurerm_subnet.subnet1.id
        private_ip_address_allocation = "Dynamic"
        # public_ip_address_id = azurerm_public_ip.this.id
    }
}

# resource "azurerm_public_ip" "this" {
#     name = "${var.prefix}-fip"
#     location = azurerm_resource_group.rg.location
#     resource_group_name = azurerm_resource_group.rg.name
#     allocation_method = "Static"
# }

# resource "azurerm_lb" "this" {
#     name = "${var.prefix}-lb"
#     location = azurerm_resource_group.rg.location
#     resource_group_name = azurerm_resource_group.rg.name

#     frontend_ip_configuration {
#       name = "PublicIPAddress"
#       public_ip_address_id = azurerm_public_ip.this.id
#     }
# }

# resource "tls_private_key" "insecure" {
#     algorithm = "RSA"
# }

# locals {
#     ssh_key_public = sensitive(tls_private_key.insecure.public_key_openssh)
# }

resource "random_password" "admin_password" {
  length      = 24
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  special     = true
}

# Create linux virtual machine
resource "azurerm_linux_virtual_machine" "vm1" {
    name = "${var.prefix}-vm1"
    resource_group_name = azurerm_resource_group.rg.name
    location = "${var.region}"
    size = "Standard_F2"
    admin_username = "tfadmin"
    # admin_password = random_password.admin_password.result
    disable_password_authentication = true

    network_interface_ids = [
        azurerm_network_interface.nic.id
    ]

    admin_ssh_key {
        username = "tfadmin"
        public_key = file("~/.ssh/id_rsa.pub")
    }

    os_disk {
        caching = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "0001-com-ubuntu-server-jammy"
        sku       = "22_04-lts"
        version   = "latest"
    }

    tags = {
        name = "Production"
    }
}

# Create windows virtual machine
resource "azurerm_windows_virtual_machine" "main" {
  name                  = "${var.prefix}-vm"
  admin_username        = "tfadmin"
  admin_password        = random_password.admin_password.result
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-datacenter-azure-edition"
    version   = "latest"
  }
}

# resource "azurerm_managed_disk" "volume1" {
#   name                 = "${var.prefix}-volume1"
#   location             = "${var.region}"
#   resource_group_name  = azurerm_resource_group.rg.name
#   storage_account_type = "Standard_LRS"
#   create_option        = "Empty"
#   disk_size_gb         = 2
# }


# resource "azurerm_virtual_machine_data_disk_attachment" "this" {
#   managed_disk_id    = azurerm_managed_disk.volume1.id
#   virtual_machine_id = azurerm_linux_virtual_machine.vm1.id
#   lun                ="2"
#   caching            = "ReadWrite"
# }