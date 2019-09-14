# // Azure location configuration
variable azure_location {
  default = "japaneast"
}


# // Azure resource configuration
variable resource_group_name {
  default = "kubespray"
}
variable resource_name_prefix {
  default = "kubespray"
}


# // admin username and public key for connection via SSH
variable admin_username {
  default = "centos"
}
variable admin_public_key {
  default = ""
}
variable contact {
  default = ""
}


# // Azure service principal for self-configuration
variable vnet_cidr {
  default = "10.10.0.0/16"
}

# // API server load balancer configuration
variable api_loadbalancer_frontend_port {
  default = 6443
}
variable api_loadbalancer_backend_port {
  default = 6443
}

# // Kubernetes master configuration
variable master_platform_fault_domain_count {
  # max 2 for the location "japaneast"
  default = 2
}
variable master_count {
  default = 3
}
variable master_vm_size {
  default = "Standard_B1ms"
}
variable master_vm_image_publisher {
  default = "OpenLogic"
}
variable master_vm_image_offer {
  default = "CentOS"
}
variable master_vm_image_sku {
  default = "7.4"
}
variable master_vm_image_version {
  default = "latest"
}
variable master_vm_osdisk_type {
  default = "Standard_LRS"
}
variable master_vm_osdisk_size_in_gb {
  default = "30"
}
variable master_subnet_cidr {
  default = "10.10.1.0/24"
}
variable domain_name_label {
  default = "kubespray"
}


# // Kubernetes node configuration
variable node_platform_fault_domain_count {
  # max 2 for the location "japaneast"
  default = 2
}
variable node_count {
  default = 3
}
variable node_vm_size {
  default = "Standard_B1ms"
}
variable node_vm_image_publisher {
  default = "OpenLogic"
}
variable node_vm_image_offer {
  default = "CentOS"
}
variable node_vm_image_sku {
  default = "7.4"
}
variable node_vm_image_version {
  default = "latest"
}
variable node_vm_osdisk_type {
  default = "Standard_LRS"
}
variable node_vm_osdisk_size_in_gb {
  default = "30"
}
variable node_subnet_cidr {
  default = "10.10.2.0/24"
}


# // Bastion Ansible host CIDR

