# LibreChat CREDS key (64 characters in hex) and 16-byte IV (32 characters in hex)
resource "random_password" "libre_app_creds_key" {
  length  = 64
  special = false
}

resource "random_password" "libre_app_creds_iv" {
  length  = 32
  special = false
}

resource "azurerm_key_vault_secret" "libre_app_creds_key" {
  name         = "${var.libre_app_name}-key"
  value        = random_password.libre_app_creds_key.result
  key_vault_id = azurerm_key_vault.az_openai_kv.id
  depends_on   = [azurerm_role_assignment.kv_role_assigment]
}

resource "azurerm_key_vault_secret" "libre_app_creds_iv" {
  name         = "${var.libre_app_name}-iv"
  value        = random_password.libre_app_creds_iv.result
  key_vault_id = azurerm_key_vault.az_openai_kv.id
  depends_on   = [azurerm_role_assignment.kv_role_assigment]
}

# LibreChat JWT Secret (64 characters in hex) and JWT Refresh Secret (64 characters in hex)
resource "random_password" "libre_app_jwt_secret" {
  length  = 64
  special = false
}

resource "random_password" "libre_app_jwt_refresh_secret" {
  length  = 64
  special = false
}

resource "azurerm_key_vault_secret" "libre_app_jwt_secret" {
  name         = "${var.libre_app_name}-jwt-secret"
  value        = random_password.libre_app_jwt_secret.result
  key_vault_id = azurerm_key_vault.az_openai_kv.id
  depends_on   = [azurerm_role_assignment.kv_role_assigment]
}

resource "azurerm_key_vault_secret" "libre_app_jwt_refresh_secret" {
  name         = "${var.libre_app_name}-jwt-refresh-secret"
  value        = random_password.libre_app_jwt_refresh_secret.result
  key_vault_id = azurerm_key_vault.az_openai_kv.id
  depends_on   = [azurerm_role_assignment.kv_role_assigment]
}

# Create app service plan for librechat app and meilisearch app
resource "azurerm_service_plan" "az_openai_asp" {
  name                = var.app_service_name
  location            = var.location
  resource_group_name = azurerm_resource_group.az_openai_rg.name
  os_type             = "Linux"
  sku_name            = var.app_service_sku_name
}

#Create LibeChat App Service
resource "azurerm_linux_web_app" "librechat" {
  name                          = var.libre_app_name
  location                      = var.location
  resource_group_name           = azurerm_resource_group.az_openai_rg.name
  service_plan_id               = azurerm_service_plan.az_openai_asp.id
  public_network_access_enabled = var.libre_app_public_network_access_enabled
  https_only                    = true

  site_config {
    minimum_tls_version = "1.2"

    # allow subnet access from built in created subnet of this module
    ip_restriction {
      virtual_network_subnet_id = var.libre_app_virtual_network_subnet_id != null ? var.libre_app_virtual_network_subnet_id : azurerm_subnet.az_openai_subnet.id
      priority                  = 100
      name                      = "${azurerm_subnet.az_openai_subnet.name}-access" # "Allow from LibreChat app subnet and hosted services e.g. cosmosdb, meilisearch etc."
      action                    = "Allow"
    }

    # ip_restriction for subnet access add additional via dynamic (optional)
    dynamic "ip_restriction" {
      for_each = var.libre_app_allowed_subnets != null ? var.libre_app_allowed_subnets : []
      content {
        virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id
        priority                  = ip_restriction.value.priority
        name                      = ip_restriction.value.name
        action                    = ip_restriction.value.action
      }
    }

    # ip_restriction for ip access add additional via dynamic (optional)
    dynamic "ip_restriction" {
      for_each = var.libre_app_allowed_ip_addresses != null ? var.libre_app_allowed_ip_addresses : []
      content {
        ip_address = ip_restriction.value.ip_address
        priority   = ip_restriction.value.priority
        name       = ip_restriction.value.name
        action     = ip_restriction.value.action
      }
    }
  }

  logs {
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
    application_logs {
      file_system_level = "Information"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings              = local.libre_app_settings
  virtual_network_subnet_id = var.libre_app_virtual_network_subnet_id != null ? var.libre_app_virtual_network_subnet_id : azurerm_subnet.az_openai_subnet.id

  depends_on = [azurerm_subnet.az_openai_subnet]
}

# Grant kv access to librechat app to reference environment variables (stored as secrets in key vault)
resource "azurerm_role_assignment" "librechat_app_kv_access" {
  scope                = azurerm_key_vault.az_openai_kv.id
  principal_id         = azurerm_linux_web_app.librechat.identity[0].principal_id
  role_definition_name = "Key Vault Secrets User" # Read secret contents. Only works for key vaults that use the 'Azure role-based access control' permission model.
}

#Custom Domain / Certificates / Allowed IPs
# resource "azurerm_dns_zone" "dns-zone" {
#   name                = var.azure_dns_zone
#   resource_group_name = var.azure_resource_group_name
# }

resource "azurerm_dns_txt_record" "domain_verification" {
  count               = var.libre_app_custom_domain_create == true ? 1 : 0
  name                = "${var.librechat_app_custom_domain_name}txt"
  zone_name           = var.librechat_app_custom_dns_zone_name
  resource_group_name = var.dns_resource_group_name
  ttl                 = 600

  record {
    value = azurerm_linux_web_app.librechat.custom_domain_verification_id
  }
}

resource "azurerm_dns_cname_record" "cname_record" {
  count               = var.libre_app_custom_domain_create == true ? 1 : 0
  name                = var.librechat_app_custom_domain_name
  zone_name           = var.librechat_app_custom_dns_zone_name
  resource_group_name = var.dns_resource_group_name
  ttl                 = 600
  record              = azurerm_linux_web_app.librechat.default_hostname

  depends_on = [azurerm_dns_txt_record.domain_verification]
}

resource "azurerm_app_service_custom_hostname_binding" "hostname_binding" {
  count               = var.libre_app_custom_domain_create == true ? 1 : 0
  hostname            = "${var.librechat_app_custom_domain_name}.${var.librechat_app_custom_dns_zone_name}"
  app_service_name    = var.libre_app_name
  resource_group_name = azurerm_resource_group.az_openai_rg.name

  depends_on = [azurerm_dns_cname_record.cname_record, azurerm_linux_web_app.librechat]
}

resource "azurerm_app_service_managed_certificate" "libre_app_cert" {
  count                      = var.libre_app_custom_domain_create == true ? 1 : 0
  custom_hostname_binding_id = azurerm_app_service_custom_hostname_binding.hostname_binding[0].id
}

resource "azurerm_app_service_certificate_binding" "libre_app_cert_binding" {
  count               = var.libre_app_custom_domain_create == true ? 1 : 0
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.hostname_binding[0].id
  certificate_id      = azurerm_app_service_managed_certificate.libre_app_cert[0].id
  ssl_state           = "SniEnabled"
}

#TODO: Implement DALL-E 
#TODO:

# Implement a Search (either Meili or Azure AI Search)
# # Generate random strings as keys for meilisearch and librechat (Stored securely in Azure Key Vault)
# resource "random_string" "meilisearch_master_key" {
#   length  = 20
#   special = false
# }

# resource "azurerm_key_vault_secret" "meilisearch_master_key" {
#   name         = "${var.meilisearch_app_name}-master-key"
#   value        = random_string.meilisearch_master_key.result
#   key_vault_id = azurerm_key_vault.az_openai_kv.id
#   depends_on   = [azurerm_role_assignment.kv_role_assigment]
# }

# Create meilisearch app
# TODO: Add support for private endpoints instead of subnet access
# resource "azurerm_linux_web_app" "meilisearch" {
#   name                = var.meilisearch_app_name
#   location            = var.location
#   resource_group_name = azurerm_resource_group.az_openai_rg.name
#   service_plan_id     = azurerm_service_plan.az_openai_asp.id
#   https_only          = true

#   app_settings = {
#     WEBSITES_ENABLE_APP_SERVICE_STORAGE = false

#     MEILI_MASTER_KEY   = var.meilisearch_app_key != null ? var.meilisearch_app_key : random_string.meilisearch_master_key.result #"@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.meilisearch_master_key.id})"
#     MEILI_NO_ANALYTICS = var.libre_app_disable_meilisearch_analytics

#     DOCKER_REGISTRY_SERVER_URL          = "https://index.docker.io"
#     WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
#     DOCKER_ENABLE_CI                    = false
#     WEBSITES_PORT                       = 7700
#     PORT                                = 7700
#     DOCKER_CUSTOM_IMAGE_NAME            = "getmeili/meilisearch:latest"
#   }

#   site_config {
#     always_on = "true"
#     ip_restriction {
#       virtual_network_subnet_id = var.meilisearch_app_virtual_network_subnet_id != null ? var.meilisearch_app_virtual_network_subnet_id : azurerm_subnet.az_openai_subnet.id
#       priority                  = 100
#       name                      = "Allow from LibreChat app subnet"
#       action                    = "Allow"
#     }
#   }

#   logs {
#     http_logs {
#       file_system {
#         retention_in_days = 7
#         retention_in_mb   = 35
#       }
#     }
#     application_logs {
#       file_system_level = "Information"
#     }
#   }

#   identity {
#     type = "SystemAssigned"
#   }

#   depends_on = [azurerm_subnet.az_openai_subnet]
# }

# Grant kv access to meilisearch app to reference the master key secret
# resource "azurerm_role_assignment" "meilisearch_app_kv_access" {
#   scope                = azurerm_key_vault.az_openai_kv.id
#   principal_id         = azurerm_linux_web_app.meilisearch.identity[0].principal_id
#   role_definition_name = "Key Vault Secrets User" # Read secret contents. Only works for key vaults that use the 'Azure role-based access control' permission model.
# }