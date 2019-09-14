output "resource_group_name" {
  value = "${var.resource_group_name}"
}

output "resource_name_prefix" {
  value = "${var.resource_name_prefix}"
}

output "fqdn" {
  value = "${azurerm_public_ip.k8s-master-lb-publicip.fqdn}"
}

output "username" {
  value = "${var.admin_username}"
}