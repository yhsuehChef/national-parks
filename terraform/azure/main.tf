# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = "${var.azure_sub_id}"
  tenant_id       = "${var.azure_tenant_id}"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "nationalparks" {
    name     = "habitat"
    location = "West US"

  tags {
    X-Contact     = "The Example Maintainer <maintainer@example.com>"
    X-Application = "national-parks"
    X-ManagedBy   = "Terraform"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "nationalparks" {
    name                = "nationalparks"
    address_space       = ["10.0.0.0/16"]
    location            = "West US"
    resource_group_name = "${azurerm_resource_group.nationalparks.name}"

  tags {
    X-Contact     = "The Example Maintainer <maintainer@example.com>"
    X-Application = "national-parks"
    X-ManagedBy   = "Terraform"
    }
}

# Create subnet
resource "azurerm_subnet" "nationalparks" {
    name                 = "nationalparks"
    resource_group_name  = "${azurerm_resource_group.nationalparks.name}"
    virtual_network_name = "${azurerm_virtual_network.nationalparks.name}"
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "nationalparks" {
    name                         = "habitat"
    location                     = "West US"
    resource_group_name          = "${azurerm_resource_group.nationalparks.name}"
    public_ip_address_allocation = "dynamic"

  tags {
    X-Contact     = "The Example Maintainer <maintainer@example.com>"
    X-Application = "national-parks"
    X-ManagedBy   = "Terraform"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nationalparks" {
    name                = "nationalparks"
    location            = "West US"
    resource_group_name = "${azurerm_resource_group.nationalparks.name}"

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
    name                       = "8080"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "9631"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "9631"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "9638"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "9638"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "27017"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27017"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
      X-Contact     = "The Example Maintainer <maintainer@example.com>"
      X-Application = "national-parks"
      X-ManagedBy   = "Terraform"
    }
}

# Create network interface
resource "azurerm_network_interface" "nationalparks" {
    name                      = "nationalparks"
    location                  = "West US"
    resource_group_name       = "${azurerm_resource_group.nationalparks.name}"
    network_security_group_id = "${azurerm_network_security_group.nationalparks.id}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${azurerm_subnet.nationalparks.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.nationalparks.id}"
    }

    tags {
      X-Contact     = "The Example Maintainer <maintainer@example.com>"
      X-Application = "national-parks"
      X-ManagedBy   = "Terraform"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.nationalparks.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "nationalparks" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.nationalparks.name}"
    location                    = "West US"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

  tags {
    X-Contact     = "The Example Maintainer <maintainer@example.com>"
    X-Application = "national-parks"
    X-ManagedBy   = "Terraform"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "nationalparks" {
    name                  = "nationalparks"
    location              = "West US"
    resource_group_name   = "${azurerm_resource_group.nationalparks.name}"
    network_interface_ids = ["${azurerm_network_interface.nationalparks.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "nationalparks-initialpeer"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "${file("${var.azure_ssh_key}")}"
        }
    }

  connection {
    user        = "azureuser"
    private_key = "${file("${var.azure_ssh_key}")}"
  }

  provisioner "file" {
    content     = "${data.template_file.install_hab.rendered}"
    destination = "/tmp/install_hab.sh"
  }

  provisioner "file" {
    content     = "${data.template_file.initial_peer.rendered}"
    destination = "/home/${var.azure_image_user}/hab-sup.service"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo adduser --group hab",
      "sudo useradd -g hab hab",
      "chmod +x /tmp/install_hab.sh",
      "sudo /tmp/install_hab.sh",
      "sudo mv /home/azureuser/hab-sup.service /etc/systemd/system/hab-sup.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl start hab-sup",
      "sudo systemctl enable hab-sup",
    ]
  }

  boot_diagnostics {
    enabled = "true"
    storage_uri = "${azurerm_storage_account.nationalparks.primary_blob_endpoint}"
  }

  tags {
    X-Contact     = "The Example Maintainer <maintainer@example.com>"
    X-Application = "national-parks"
    X-ManagedBy   = "Terraform"
  }
}

////////////////////////////////
// Templates

data "template_file" "initial_peer" {
  template = "${file("../templates/hab-sup.service")}"

  vars {
    flags = "--auto-update --listen-gossip 0.0.0.0:9638 --listen-http 0.0.0.0:9631 --permanent-peer"
  }
}

data "template_file" "sup_service" {
  template = "${file("../templates/hab-sup.service")}"

  vars {
    flags = "--auto-update --peer 127.0.0.1 --listen-gossip 0.0.0.0:9638 --listen-http 0.0.0.0:9631"
  }
}

data "template_file" "install_hab" {
  template = "${file("../templates/install-hab.sh")}"
}
