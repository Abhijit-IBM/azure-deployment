
# output "ssh_private_key" {
#     value = tls_private_key.insecure.private_key_pem
#     sensitive = true
# }

output "admin_password" {
  sensitive = true
  value     = azurerm_windows_virtual_machine.main.admin_password
}