###############################
# Outputs
###############################
output "resource_group_name" {
  description = "The name of the resource group."
  value       = azurerm_resource_group.prod_rg.name
}

output "web_lb_public_ip" {
  description = "Public IP address of the web load balancer."
  value       = azurerm_public_ip.web_lb.ip_address
}

output "web_vmss_id" {
  description = "ID of the web VM Scale Set."
  value       = azurerm_linux_virtual_machine_scale_set.web_vmss.id
}

output "postgres_flexible_server_fqdn" {
  description = "FQDN of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.db.fqdn
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.log.id
}

output "dns_zone_name" {
  description = "DNS zone name for the web servers."
  value       = azurerm_dns_zone.web_dns.name
}

output "dns_a_record_fqdn" {
  description = "FQDN of the DNS A record for the web servers."
  value       = azurerm_dns_a_record.web.fqdn
}
