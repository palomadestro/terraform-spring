resource "azurerm_storage_account" "storage_aula" {
    name                        = "storageaulavm"
    resource_group_name         = azurerm_resource_group.rg_aula.name
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "aula infra"
    }

    depends_on = [ azurerm_resource_group.rg_aula ]
}

resource "azurerm_linux_virtual_machine" "vm_aula" {
    name                  = "myVM"
    location              = var.location
    resource_group_name   = azurerm_resource_group.rg_aula.name
    network_interface_ids = [azurerm_network_interface.nic_aula.id]
    size                  = "Standard_E2bs_v5"

    os_disk {
        name              = "myOsAppDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "myvm"
    admin_username = var.user
    admin_password = var.password
    disable_password_authentication = false

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.storage_aula.primary_blob_endpoint
    }

    tags = {
        environment = "aula infra"
    }

    depends_on = [ azurerm_resource_group.rg_aula, azurerm_network_interface.nic_aula, azurerm_storage_account.storage_aula, azurerm_public_ip.publicip_aula ]
}

resource "null_resource" "upload1" {
    provisioner "file" {
        connection {
            type = "ssh"
            user = var.user
            password = var.password
            host = data.azurerm_public_ip.ip_aula_data.ip_address
        }
        source = "springapp"
        destination = "/home/azureuser"
    }

    depends_on = [azurerm_linux_virtual_machine.vm_aula]
}

resource "null_resource" "deploy" {
    triggers = {
        order = null_resource.upload1.id
    }
    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user = var.user
            password = var.password
            host = data.azurerm_public_ip.ip_aula_data.ip_address
        }
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y openjdk-11-jre unzip",
            "mkdir /home/azureuser/springmvcapp",
            "rm -rf /home/azureuser/springmvcapp/*.*",
            "unzip -o /home/azureuser/springapp/springapp.zip -d /home/azureuser/springmvcapp",
            "sudo mkdir -p /var/log/springapp",
            "sudo cp /home/azureuser/springapp/springapp.service /etc/systemd/system/springapp.service",
            "sudo systemctl start springapp.service",
            "sudo systemctl enable springapp.service"
        ]
    }
}
