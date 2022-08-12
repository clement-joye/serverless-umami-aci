################################## PROVIDERS ##################################
# --------------------------------------------------------------------------- #
###############################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.10.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

################################## RESOURCES ##################################
# -------------------------------------------------------------------------- -#
###############################################################################

data "azurerm_subscription" "primary" {
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_name}"
  location = var.location
}

################################## STORAGE ACCOUNT ##################################

resource "azurerm_storage_account" "sa" {
  name                      = "sa${var.project_name}"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true
}

resource "azurerm_storage_share" "caddy_share_umami_prod" {
  name                 = "aci-caddy-umami-prod"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 1
}

resource "azurerm_servicebus_namespace" "sbn" {
  name                = "sbn-${var.project_name}-prod"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"
}

################################## SERVICE BUS ##################################

resource "azurerm_servicebus_queue" "queue" {
  name         = "umami"
  namespace_id = azurerm_servicebus_namespace.sbn.id
}

resource "azurerm_servicebus_queue_authorization_rule" "queue_policy" {
  name     = "umami_policy"
  queue_id = azurerm_servicebus_queue.queue.id

  listen = true
  send   = true
  manage = false
}

################################## POSTGRESQL FLEXIBLE SERBER ##################################

resource "random_string" "hash_salt" {
  length           = 16
  special          = false
}

resource "random_string" "db_admin" {
  length           = 16
  special          = false
  numeric          = false 
}

resource "random_password" "db_admin" {
  length           = 16
  special          = true
  override_special = "!#$%&?<>[]()"
}

resource "azurerm_postgresql_flexible_server" "db" {
  name                   = "db-${var.project_name}-prod"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "12"
  administrator_login    = random_string.db_admin.result
  administrator_password = random_password.db_admin.result
  storage_mb = 32768
  sku_name   = "B_Standard_B2s"
  zone       = 1    
}

resource "azurerm_postgresql_flexible_server_database" "db_umami" {
  name      = "umami"
  server_id = azurerm_postgresql_flexible_server.db.id
  collation = "en_US.UTF8"
  charset   = "UTF8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "db_firewall_rule" {
  name                = "allow-azure-services"
  server_id         = azurerm_postgresql_flexible_server.db.id
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

################################## STATIC WEB APP ##################################

resource "azurerm_static_site" "sw" {
  name                = "sw-${var.project_name}-prod"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.alternate_location
  sku_tier            = "Free"
  sku_size            = "Free"
}

resource "azurerm_resource_group_template_deployment" "sw_appsettings" {
  deployment_mode     = "Incremental"
  name                = "sw-appsettings"
  resource_group_name = azurerm_resource_group.rg.name

  template_content = file("staticwebapp-arm-staticsite-config.json")
  parameters_content = jsonencode({
    staticSiteName = {
      value = azurerm_static_site.sw.name
    },
    clientIpHeader = {
      value = "custom-client-ip"
    },
    serviceBusConnString = {
      value = azurerm_servicebus_queue_authorization_rule.queue_policy.secondary_connection_string
    },
    serviceBusQueueName = {
      value = "umami"
    },
    umamiEndpoint = {
      value = "https://aci-${var.project_name}-prod.${var.location}.azurecontainer.io"
    },
    apiEndpoint = {
      value = "https://${azurerm_static_site.sw.default_host_name}"
    },
    updateAciUrl = {
      value = "https://fa-${var.project_name}-ps-prod.azurewebsites.net/api/UpdateAci?code=${data.azurerm_function_app_host_keys.fa_host_keys.default_function_key}"
    }
  })
}

################################## FUNCTION APP ##################################

resource "azurerm_service_plan" "asp" {
  name                = "asp-${var.project_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.alternate_location
  os_type             = "Windows"
  sku_name            = "Y1"
}

resource "azurerm_application_insights" "appi" {
  name                = "ai-${var.project_name}-prod"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.alternate_location
  application_type    = "other"
}

resource "azurerm_windows_function_app" "fa_ps" {
  name                        = "fa-${var.project_name}-ps-prod"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = var.alternate_location
  service_plan_id             = azurerm_service_plan.asp.id
  storage_account_name        = azurerm_storage_account.sa.name
  storage_account_access_key  = azurerm_storage_account.sa.primary_access_key
  functions_extension_version = "~4"
  https_only                  = true

  site_config {
    application_insights_key = "${azurerm_application_insights.appi.instrumentation_key}"
    application_stack {
      powershell_core_version = 7
    }
  }

  identity { 
    type = "SystemAssigned" 
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "powershell"
    "WEBSITE_RUN_FROM_PACKAGE"       = "1"
    "RESOURCE_GROUP_NAME"            = "rg-${var.project_name}"
    "SUBSCRIPTION_ID"                = var.subscription_id
    "UMAMI_CONTAINER_GROUP_NAME"     = "aci-${var.project_name}-prod"
    "UMAMI_DB_NAME"                  = azurerm_postgresql_flexible_server.db.name
    "UMAMI_ACI_URL"                  = "https://aci-${var.project_name}-prod.${var.location}.azurecontainer.io"
  }
}

resource "azurerm_windows_function_app" "fa_js" {
  name                        = "fa-${var.project_name}-js-prod"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = var.alternate_location
  service_plan_id             = azurerm_service_plan.asp.id
  storage_account_name        = azurerm_storage_account.sa.name
  storage_account_access_key  = azurerm_storage_account.sa.primary_access_key
  functions_extension_version = "~4"
  https_only                  = true

  site_config {
    application_insights_key = "${azurerm_application_insights.appi.instrumentation_key}"
  }

  identity { 
    type = "SystemAssigned" 
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "node"
    "WEBSITE_NODE_DEFAULT_VERSION"   = "~14"
    "WEBSITE_RUN_FROM_PACKAGE"       = "1"
    "SERVICE_BUS_CONNSTRING"         = azurerm_servicebus_queue_authorization_rule.queue_policy.secondary_connection_string
    "SERVICE_BUS_QUEUE_NAME"         = "umami"
    "UMAMI_ENDPOINT"                 = "https://aci-${var.project_name}-prod.${var.location}.azurecontainer.io"
    "UPDATE_ACI_URL"                 = "https://fa-${var.project_name}-ps-prod.azurewebsites.net/api/UpdateAci?code=${data.azurerm_function_app_host_keys.fa_host_keys.default_function_key}"
    "API_ENDPOINT"                   = "https://fa-${var.project_name}-js-prod.azurewebsites.net"
  }
}

resource "azurerm_role_assignment" "role" {
  scope                = "${data.azurerm_subscription.primary.id}/resourceGroups/${azurerm_resource_group.rg.name}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_windows_function_app.fa_ps.identity[0].principal_id
}

################################## AZURE CONTAINER INSTANCE ##################################

resource "azurerm_container_group" "aci" {
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = var.location
  name                      = "aci-${var.project_name}-prod"
  os_type                   = "Linux"
  dns_name_label            = "aci-${var.project_name}-prod"
  ip_address_type           = "Public"
  restart_policy            = "OnFailure"

  identity { 
    type = "SystemAssigned" 
  }

  depends_on = [
    azurerm_postgresql_flexible_server_firewall_rule.db_firewall_rule
  ]

  container {
    name   = "umami"
    image  = "clementjoye/timestamp-enabled-umami:latest"
    cpu    = "0.5"
    memory = "1.0"
    environment_variables = {
      FUNCTION_APP_URL    = "https://fa-${var.project_name}-ps-prod.azurewebsites.net/api/UpdateAci?action=stop&code=${data.azurerm_function_app_host_keys.fa_host_keys.default_function_key}"
      DATABASE_URL = "postgresql://${random_string.db_admin.result}:${random_password.db_admin.result}@${azurerm_postgresql_flexible_server.db.fqdn}/umami?ssl=true"
      DATABASE_TYPE = "postgresql"
      HASH_SALT = random_string.hash_salt.result
      PORT = "3000"
      FORCE_SSL = 1
      CLIENT_IP_HEADER = "custom-client-ip"
    }
  }

  container {
    name   = "caddy"
    image  = "caddy"
    cpu    = "0.5"
    memory = "0.5"

    ports {
      port     = 443
      protocol = "TCP"
    }

    ports {
      port     = 80
      protocol = "TCP"
    }

    volume {
      name                 = "aci-caddy-data-prod"
      mount_path           = "/data"
      storage_account_name = azurerm_storage_account.sa.name
      storage_account_key  = azurerm_storage_account.sa.primary_access_key
      share_name           = azurerm_storage_share.caddy_share_umami_prod.name
    }

    commands = ["caddy", "reverse-proxy", "--from", "aci-${var.project_name}-prod.${azurerm_resource_group.rg.location}.azurecontainer.io", "--to", "localhost:3000"]
  }
}

data "azurerm_function_app_host_keys" "fa_host_keys" {
  name                = azurerm_windows_function_app.fa_ps.name
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [azurerm_windows_function_app.fa_ps]
}

################################## OUTPUT ##################################

output "umami_url" {
  value = "https://${azurerm_container_group.aci.fqdn}"
  description = "URL"
}

output "sw_url" {
  value = "https://${azurerm_static_site.sw.default_host_name}"
  description = "URL"
}

output "admin_name" {
  value = random_string.db_admin.result
  description = "The username for logging in to the database."
  sensitive   = true
}

output "admin_pwd" {
  value = random_password.db_admin.result
  description = "The password for logging in to the database."
  sensitive   = true
}

output "sw_api_key" {
  value = azurerm_static_site.sw.api_key 
  description = "The publish profile Key to deploy from GitHub action."
  sensitive   = true
}

output "queue_access_key" {
  value = azurerm_servicebus_queue_authorization_rule.queue_policy.secondary_connection_string
  description = "The access key to read/send messages from the azure service bus queue."
  sensitive   = true
}