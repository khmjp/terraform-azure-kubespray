# -----------------------------------------------------------------
# SETUP PROVIDER AND BACKEND
# -----------------------------------------------------------------

provider "azurerm" {
  #version = ">= 1.3.0"

  #subscription_id = "${var.azure_subscription_id}"
  #tenant_id       = "${var.azure_tenant_id}"
}

#terraform {
#  backend "azurerm" {}
#}

# -----------------------------------------------------------------
# CREATE RESOURCE GROUP
# -----------------------------------------------------------------
resource "azurerm_resource_group" "kubespray" {
  name     = "${var.resource_group_name}"
  location = "${var.azure_location}"

  tags = {
    Contact = "${var.contact}"
  }
}

# -----------------------------------------------------------------
# CREATE AVAILABILTY SETS FOR MASTER AND NODE NODES
# -----------------------------------------------------------------

resource "azurerm_availability_set" "kubespray-master-as" {
  name                = "kubespray-master-as"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  managed                      = "true"
  platform_fault_domain_count  = "${var.master_platform_fault_domain_count}"
  platform_update_domain_count = 10
}

resource "azurerm_availability_set" "kubespray-node-as" {
  name                = "kubespray-node-as"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  managed                      = "true"
  platform_fault_domain_count  = "${var.node_platform_fault_domain_count}"
  platform_update_domain_count = 10
}

# -----------------------------------------------------------------
# SETUP VIRTUAL NETWORKS WITH SUBNETS FOR MASTERS AND NODES
# -----------------------------------------------------------------

resource "azurerm_route_table" "kubespray-routetable" {
  name                = "${var.resource_name_prefix}-routetable"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"
}

resource "azurerm_virtual_network" "kubespray-vnet" {
  name                = "${var.resource_name_prefix}-vnet"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  address_space = [
    "${var.vnet_cidr}",
  ]
}

resource "azurerm_subnet" "kubespray-master-subnet" {
  name                = "${var.resource_name_prefix}-master-subnet"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  virtual_network_name = "${azurerm_virtual_network.kubespray-vnet.name}"
  address_prefix       = "${var.master_subnet_cidr}"
}

resource "azurerm_subnet" "kubespray-node-subnet" {
  name                = "${var.resource_name_prefix}-node-subnet"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  virtual_network_name = "${azurerm_virtual_network.kubespray-vnet.name}"
  address_prefix       = "${var.node_subnet_cidr}"
}

resource "azurerm_network_security_group" "kubespray-master-nsg" {
  name                = "${var.resource_name_prefix}-nsg"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"
}

resource "azurerm_network_security_group" "kubespray-node-nsg" {
  name                = "${var.resource_name_prefix}-nsg"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"
}

resource "azurerm_network_security_rule" "kubespray-master-nsr_ssh" {
  name                        = "pub_inbound_22_tcp_ssh"
  resource_group_name         = "${azurerm_resource_group.kubespray.name}"
  network_security_group_name = "${azurerm_network_security_group.kubespray-master-nsg.name}"

  description                = "Allows inbound internet traffic to 22/TCP (SSH daemon)"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "Internet"
  destination_address_prefix = "*"
  access                     = "Allow"
  priority                   = 100
  direction                  = "Inbound"
}

resource "azurerm_network_security_rule" "kubespray-master-nsr_kubeapi" {
  name                        = "pub_inbound_tcp_kubeapi"
  resource_group_name         = "${azurerm_resource_group.kubespray.name}"
  network_security_group_name = "${azurerm_network_security_group.kubespray-master-nsg.name}"

  description                = "Allows inbound internet traffic to ${var.api_loadbalancer_frontend_port}/TCP (Kubernetes API SSL port)"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "${var.api_loadbalancer_frontend_port}"
  source_address_prefix      = "Internet"
  destination_address_prefix = "*"
  access                     = "Allow"
  priority                   = 101
  direction                  = "Inbound"
}

resource "azurerm_network_security_rule" "kubespray-node-nsr_ssh" {
  name                        = "pub_inbound_22_tcp_ssh"
  resource_group_name         = "${azurerm_resource_group.kubespray.name}"
  network_security_group_name = "${azurerm_network_security_group.kubespray-node-nsg.name}"

  description                = "Allows inbound internet traffic to 22/TCP (SSH daemon)"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "Internet"
  destination_address_prefix = "*"
  access                     = "Allow"
  priority                   = 100
  direction                  = "Inbound"
}

# -----------------------------------------------------------------
# CREATE PUBLIC IP FOR MASTER API ACCESS
# -----------------------------------------------------------------

resource "azurerm_public_ip" "k8s-master-lb-publicip" {
  name                = "${var.resource_name_prefix}-master-lb-publicip"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  allocation_method = "Static"
  domain_name_label = "${var.domain_name_label}"
}

# -----------------------------------------------------------------
# CREATE LOADBALANCER FOR MASTERS
# -----------------------------------------------------------------

resource "azurerm_lb" "k8s-master-lb" {
  name                = "${var.resource_name_prefix}-master-lb"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  frontend_ip_configuration {
    name                 = "${var.resource_name_prefix}-master-frontend"
    public_ip_address_id = "${azurerm_public_ip.k8s-master-lb-publicip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "k8s-master-lb-bepool" {
  name                = "${var.resource_name_prefix}-master-backend"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  loadbalancer_id = "${azurerm_lb.k8s-master-lb.id}"
}

# -----------------------------------------------------------------
# CREATE LB RULES for API ACCESS ON MASTERS
# -----------------------------------------------------------------

resource "azurerm_lb_rule" "k8s-api-lb-rule" {
  name                = "${var.resource_name_prefix}-api"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.k8s-master-lb-bepool.id}"
  loadbalancer_id                = "${azurerm_lb.k8s-master-lb.id}"
  probe_id                       = "${azurerm_lb_probe.k8s-api-lb-probe.id}"
  frontend_ip_configuration_name = "${var.resource_name_prefix}-master-frontend"

  protocol                = "Tcp"
  frontend_port           = "${var.api_loadbalancer_frontend_port}"
  backend_port            = "${var.api_loadbalancer_backend_port}"
  enable_floating_ip      = false
  idle_timeout_in_minutes = 5
}

// Load balancer TCP probe that checks if the nodes are available
resource "azurerm_lb_probe" "k8s-api-lb-probe" {
  name                = "${var.resource_name_prefix}-api"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  loadbalancer_id     = "${azurerm_lb.k8s-master-lb.id}"
  port                = "${var.api_loadbalancer_backend_port}"
  interval_in_seconds = 5
  number_of_probes    = 2
}

# -----------------------------------------------------------------
# CREATE NAT RULES FOR SSH TO MASTERS AND NODES
# -----------------------------------------------------------------

resource "azurerm_lb_nat_rule" "ssh-master-nat" {
  count = "${var.master_count}"

  resource_group_name            = "${azurerm_resource_group.kubespray.name}"
  loadbalancer_id                = "${azurerm_lb.k8s-master-lb.id}"
  name                           = "ssh-master-${format("%03d", count.index + 1)}"
  protocol                       = "Tcp"
  frontend_port                  = "222${count.index + 1}"
  backend_port                   = 22
  frontend_ip_configuration_name = "${var.resource_name_prefix}-master-frontend"
}

resource "azurerm_lb_nat_rule" "ssh-node-nat" {
  count = "${var.node_count}"

  resource_group_name            = "${azurerm_resource_group.kubespray.name}"
  loadbalancer_id                = "${azurerm_lb.k8s-master-lb.id}"
  name                           = "ssh-node-${format("%03d", count.index + 1)}"
  protocol                       = "Tcp"
  frontend_port                  = "232${count.index + 1}"
  backend_port                   = 22
  frontend_ip_configuration_name = "${var.resource_name_prefix}-master-frontend"
}

# -----------------------------------------------------------------
# CREATE PUBLIC IP FOR MASTER SSH ACCESS
# -----------------------------------------------------------------

resource "azurerm_public_ip" "k8s-master-publicip" {
  count = "${var.master_count}"

  name                = "${var.resource_name_prefix}-master-${format("%03d", count.index + 1)}-publicip"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  allocation_method = "Static"
}

# -----------------------------------------------------------------
# CREATE NETWORK INTERFACES FOR MASTERS
# -----------------------------------------------------------------

resource "azurerm_network_interface" "k8s-master-nic" {
  count = "${var.master_count}"

  name                = "${var.resource_name_prefix}-master-${format("%03d", count.index + 1)}-nic"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  network_security_group_id = "${azurerm_network_security_group.kubespray-master-nsg.id}"
  enable_ip_forwarding      = true

  ip_configuration {
    name                                    = "${var.resource_name_prefix}-master-nic-ipconfig"
    subnet_id                               = "${azurerm_subnet.kubespray-master-subnet.id}"
    private_ip_address_allocation           = "dynamic"
    public_ip_address_id                    = "${element(azurerm_public_ip.k8s-master-publicip.*.id, count.index)}" 
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.k8s-master-lb-bepool.id}"]
    load_balancer_inbound_nat_rules_ids     = ["${element(azurerm_lb_nat_rule.ssh-master-nat.*.id, count.index)}"]
  }
}

# -----------------------------------------------------------------
# CREATE MASTERS
# -----------------------------------------------------------------

resource "azurerm_virtual_machine" "k8s-master-vm" {
  count = "${var.master_count}"

  name                = "${var.resource_name_prefix}-master-${format("%03d", count.index + 1)}-vm"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  vm_size             = "${var.master_vm_size}"
  availability_set_id = "${azurerm_availability_set.kubespray-master-as.id}"

  network_interface_ids = [
    "${element(azurerm_network_interface.k8s-master-nic.*.id, count.index)}",
  ]

  storage_image_reference {
    publisher = "${var.master_vm_image_publisher}"
    offer     = "${var.master_vm_image_offer}"
    sku       = "${var.master_vm_image_sku}"
    version   = "${var.master_vm_image_version}"
  }

  storage_os_disk {
    name              = "${var.resource_name_prefix}-master-${format("%03d", count.index + 1)}-osdisk"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.master_vm_osdisk_size_in_gb}"
    managed_disk_type = "${var.master_vm_osdisk_type}"
  }

  os_profile {
    computer_name  = "${var.resource_name_prefix}-master-${format("%03d", count.index + 1)}"
    admin_username = "${var.admin_username}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${var.admin_public_key}"
    }
  }

  tags = {
    roles       = "kube-master,etcd"
    k8s-cluster = ""
    kube-master = ""
    etcd        = ""
  }
}

# -----------------------------------------------------------------
# CREATE PUBLIC IP FOR NODE SSH ACCESS
# -----------------------------------------------------------------

resource "azurerm_public_ip" "k8s-node-publicip" {
  count = "${var.node_count}"

  name                = "${var.resource_name_prefix}-node-${format("%03d", count.index + 1)}-publicip"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  allocation_method = "Static"
}

# -----------------------------------------------------------------
# CREATE NETWORK INTERFACES FOR NODES
# -----------------------------------------------------------------

resource "azurerm_network_interface" "k8s-node-nic" {
  count = "${var.node_count}"

  name                = "${var.resource_name_prefix}-node-${format("%03d", count.index + 1)}-nic"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  network_security_group_id = "${azurerm_network_security_group.kubespray-node-nsg.id}"
  enable_ip_forwarding      = true

  ip_configuration {
    name                          = "${var.resource_name_prefix}-node-nic-ipconfig"
    subnet_id                     = "${azurerm_subnet.kubespray-node-subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${element(azurerm_public_ip.k8s-node-publicip.*.id, count.index)}" 
  }
}

# -----------------------------------------------------------------
# CREATE NODES
# -----------------------------------------------------------------

resource "azurerm_virtual_machine" "k8s-node-vm" {
  count = "${var.node_count}"

  name                = "${var.resource_name_prefix}-node-${format("%03d", count.index + 1)}-vm"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.kubespray.name}"

  vm_size             = "${var.node_vm_size}"
  availability_set_id = "${azurerm_availability_set.kubespray-node-as.id}"

  network_interface_ids = [
    "${element(azurerm_network_interface.k8s-node-nic.*.id, count.index)}",
  ]

  storage_image_reference {
    publisher = "${var.node_vm_image_publisher}"
    offer     = "${var.node_vm_image_offer}"
    sku       = "${var.node_vm_image_sku}"
    version   = "${var.node_vm_image_version}"
  }

  storage_os_disk {
    name              = "${var.resource_name_prefix}-node-${format("%03d", count.index + 1)}-osdisk"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.node_vm_osdisk_size_in_gb}"
    managed_disk_type = "${var.node_vm_osdisk_type}"
  }

  os_profile {
    computer_name  = "${var.resource_name_prefix}-master-${format("%03d", count.index + 1)}"
    admin_username = "${var.admin_username}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${var.admin_public_key}"
    }
  }

  tags = {
    roles       = "kube-node"
    k8s-cluster = ""
    kube-master = ""
    etcd        = ""
  }
}
