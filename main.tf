###############################
# Provider Configuration
###############################
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.70.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

###############################
# Resource Group
###############################
resource "azurerm_resource_group" "prod_rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

###############################
# Virtual Network & Subnets
###############################
resource "azurerm_virtual_network" "prod_vnet" {
  name                = var.vnet_name
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "web" {
  name                 = var.web_subnet_name
  resource_group_name  = azurerm_resource_group.prod_rg.name
  virtual_network_name = azurerm_virtual_network.prod_vnet.name
  address_prefixes     = [var.web_subnet_prefix]
}

resource "azurerm_subnet" "db" {
  name                 = var.db_subnet_name
  resource_group_name  = azurerm_resource_group.prod_rg.name
  virtual_network_name = azurerm_virtual_network.prod_vnet.name
  address_prefixes     = [var.db_subnet_prefix]
}

###############################
# Network Security Groups
###############################
resource "azurerm_network_security_group" "web_nsg" {
  name                = "${var.web_subnet_name}-nsg"
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name
  tags                = local.common_tags

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web_nsg_assoc" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

resource "azurerm_network_security_group" "db_nsg" {
  name                = "${var.db_subnet_name}-nsg"
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name
  tags                = local.common_tags

  security_rule {
    name                       = "Allow-Postgres-From-Web"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = azurerm_subnet.web.address_prefixes[0]
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "db_nsg_assoc" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}

###############################
# VM Scale Set for Web Tier
###############################
resource "azurerm_linux_virtual_machine_scale_set" "web_vmss" {
  name                = var.vmss_name
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name
  sku                 = var.vm_size
  instances           = var.vmss_capacity_default
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  computer_name_prefix = "webvm"
  upgrade_mode        = "Automatic"
  overprovision       = false
  zones               = ["1"]

  source_image_reference {
    publisher = var.vm_image_publisher
    offer     = var.vm_image_offer
    sku       = var.vm_image_sku
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "webvmss-nic"
    primary = true
    ip_configuration {
      name                                   = "webvmss-ipconfig"
      subnet_id                              = azurerm_subnet.web.id
      load_balancer_backend_address_pool_ids  = [azurerm_lb_backend_address_pool.web_backend.id]
      primary                                = true
    }
  }

  custom_data = base64encode(file("${path.module}/cloud-init-web.sh"))

  tags = local.common_tags
}

###############################
# Load Balancer for Web Tier
###############################
resource "azurerm_public_ip" "web_lb" {
  name                = "web-lb-pip"
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_lb" "web_lb" {
  name                = "web-lb"
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "web-lb-frontend"
    public_ip_address_id = azurerm_public_ip.web_lb.id
  }
  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "web_backend" {
  name                = "web-lb-backend"
  loadbalancer_id     = azurerm_lb.web_lb.id
}

resource "azurerm_lb_probe" "web_health_probe" {
  name                = "web-health-probe"
  resource_group_name = azurerm_resource_group.prod_rg.name
  loadbalancer_id     = azurerm_lb.web_lb.id
  protocol            = "Tcp"
  port                = 80
}

resource "azurerm_lb_rule" "web_lb_rule" {
  name                           = "http-rule"
  resource_group_name            = azurerm_resource_group.prod_rg.name
  loadbalancer_id                = azurerm_lb.web_lb.id
  protocol                      = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "web-lb-frontend"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.web_backend.id
  probe_id                      = azurerm_lb_probe.web_health_probe.id
}

###############################
# Autoscale for VMSS
###############################
resource "azurerm_monitor_autoscale_setting" "web_vmss_autoscale" {
  name                = "web-vmss-autoscale"
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web_vmss.id
  enabled             = true
  profile {
    name = "default"
    capacity {
      minimum = 1
      maximum = 5
      default = var.vmss_capacity_default
    }
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }
  }
  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
      custom_emails                        = [var.alert_email]
    }
  }
  tags = local.common_tags
}

###############################
# Azure Database for PostgreSQL Flexible Server
###############################
resource "azurerm_postgresql_flexible_server" "db" {
  name                   = var.postgres_server_name
  resource_group_name    = azurerm_resource_group.prod_rg.name
  location               = azurerm_resource_group.prod_rg.location
  version                = var.postgres_version
  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password
  storage_mb             = var.postgres_storage_mb
  sku_name               = var.postgres_sku
  zone                   = "1"
  high_availability {
    mode = var.postgres_ha_mode
  }
  backup {
    backup_retention_days        = var.postgres_backup_retention_days
    geo_redundant_backup_enabled = var.postgres_geo_backup
  }
  storage_auto_grow_enabled = true
  delegated_subnet_id       = azurerm_subnet.db.id
  tags                     = local.common_tags
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_web" {
  name             = "AllowWebSubnet"
  server_id        = azurerm_postgresql_flexible_server.db.id
  start_ip_address = cidrhost(azurerm_subnet.web.address_prefixes[0], 1)
  end_ip_address   = cidrhost(azurerm_subnet.web.address_prefixes[0], 254)
}

###############################
# Azure Monitor & Log Analytics
###############################
resource "azurerm_log_analytics_workspace" "log" {
  name                = "${var.resource_group_name}-log"
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.common_tags
}

resource "azurerm_monitor_diagnostic_setting" "vmss_diag" {
  name                       = "vmss-diagnostics"
  target_resource_id         = azurerm_linux_virtual_machine_scale_set.web_vmss.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id
  log {
    category = "Administrative"
    enabled  = true
  }
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "postgres_diag" {
  name                       = "postgres-diagnostics"
  target_resource_id         = azurerm_postgresql_flexible_server.db.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id
  log {
    category = "PostgreSQLLogs"
    enabled  = true
  }
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

###############################
# Azure Security Center (Defender for Cloud)
###############################
resource "azurerm_security_center_subscription_pricing" "defender" {
  tier          = "Free"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "defender_sql" {
  tier          = "Free"
  resource_type = "SqlServers"
}

###############################
# Azure DNS Zone
###############################
resource "azurerm_dns_zone" "web_dns" {
  name                = var.dns_zone_name
  resource_group_name = azurerm_resource_group.prod_rg.name
  tags                = local.common_tags
}

resource "azurerm_dns_a_record" "web" {
  name                = var.dns_record_name
  zone_name           = azurerm_dns_zone.web_dns.name
  resource_group_name = azurerm_resource_group.prod_rg.name
  ttl                 = 300
  records             = [azurerm_public_ip.web_lb.ip_address]
}

###############################
# Azure Backup for VMs
###############################
resource "azurerm_recovery_services_vault" "vault" {
  name                = "${var.resource_group_name}-vault"
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_backup_policy_vm" "vm_policy" {
  name                = "prod-vm-policy"
  resource_group_name = azurerm_resource_group.prod_rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  backup {
    frequency = "Daily"
    time      = "23:00"
  }
  retention_daily {
    count = var.vm_backup_retention_days
  }
  retention_weekly {
    count    = 2
    weekdays = ["Sunday"]
  }
  retention_monthly {
    count    = 1
    weekdays = ["Sunday"]
    weeks    = [1]
  }
}

resource "azurerm_backup_protected_vm" "web_vmss" {
  resource_group_name = azurerm_resource_group.prod_rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  source_vm_id        = azurerm_linux_virtual_machine_scale_set.web_vmss.id
  backup_policy_id    = azurerm_backup_policy_vm.vm_policy.id
}

###############################
# Cost Management Budget
###############################
resource "azurerm_consumption_budget_subscription" "prod_budget" {
  name            = "prod-budget"
  subscription_id = data.azurerm_client_config.current.subscription_id
  amount          = var.budget_amount
  time_grain      = "Monthly"
  time_period {
    start_date = var.budget_start_date
  }
  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = [var.alert_email]
  }
  notification {
    enabled        = true
    threshold      = 90
    operator       = "GreaterThan"
    contact_emails = [var.alert_email]
  }
  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    contact_emails = [var.alert_email]
  }
}

data "azurerm_client_config" "current" {}

###############################
# Locals for Tagging
###############################
locals {
  common_tags = {
    Environment = "Prod"
    Service     = "Web"
    CostCenter  = var.cost_center
    Owner       = var.owner
  }
}
