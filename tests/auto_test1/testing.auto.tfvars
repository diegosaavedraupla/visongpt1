### 01 Common Variables + RG ###
resource_group_name = "TF-Module-Automated-Tests-Cognitive-GPT"
location            = "uksouth"
tags = {
  Terraform   = "True"
  Description = "Private ChatGPT hosted on Azure OpenAI (Librechat)"
  Author      = "Marcel Lupo"
  GitHub      = "https://github.com/Pwd9000-ML/terraform-azurerm-openai-private-chatgpt"
}

### 02 networking ###
virtual_network_name = "openaivnet"
vnet_address_space   = ["10.4.0.0/24"]
subnet_config = {
  subnet_name                                   = "app-cosmos-sub"
  subnet_address_space                          = ["10.4.0.0/24"]
  service_endpoints                             = ["Microsoft.AzureCosmosDB", "Microsoft.Web", "Microsoft.KeyVault"]
  private_endpoint_network_policies_enabled     = false
  private_link_service_network_policies_enabled = false
  subnets_delegation_settings = {
    app-service-plan = [
      {
        name    = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    ]
  }
}

### 03 KeyVault ###
kv_name              = "openaikv"
kv_sku               = "standard"
kv_fw_default_action = "Deny"
kv_fw_bypass         = "AzureServices"
kv_fw_allowed_ips    = ["0.0.0.0/0"]

### 04 Create OpenAI Service ###
oai_account_name                       = "gptopenaiaccount"
oai_sku_name                           = "S0"
oai_custom_subdomain_name              = "gptopenai"
oai_dynamic_throttling_enabled         = false
oai_fqdns                              = []
oai_local_auth_enabled                 = true
oai_outbound_network_access_restricted = false
oai_public_network_access_enabled      = true
oai_customer_managed_key               = null
oai_identity = {
  type = "SystemAssigned"
}
oai_network_acls = null
oai_storage      = null
oai_model_deployment = [
  {
    deployment_id  = "gpt-4"
    model_name     = "gpt-4"
    model_format   = "OpenAI"
    model_version  = "1106-Preview"
    scale_type     = "Standard"
    scale_capacity = 10 # 34K == Roughly 204 RPM (Requests per minute)
  }
]

### 05 cosmosdb ###

cosmosdb_name                    = "gptcosmosdb"
cosmosdb_offer_type              = "Standard"
cosmosdb_kind                    = "MongoDB"
cosmosdb_automatic_failover      = false
use_cosmosdb_free_tier           = true
cosmosdb_consistency_level       = "BoundedStaleness"
cosmosdb_max_interval_in_seconds = 10
cosmosdb_max_staleness_prefix    = 200
cosmosdb_geo_locations = [
  {
    location          = "uksouth"
    failover_priority = 0
  }
]
cosmosdb_capabilities                      = ["EnableMongo", "MongoDBv3.4"]
cosmosdb_virtual_network_subnets           = null
cosmosdb_is_virtual_network_filter_enabled = true
cosmosdb_public_network_access_enabled     = true

# ### log analytics workspace for container apps ###
# #laws_name              = "gptlaws"
# #laws_sku               = "PerGB2018"
# #laws_retention_in_days = 30

# ### Container App Enviornment ###
# #cae_name = "gptcae"

# ### Container App ###
# #ca_name          = "gptca"
# #ca_revision_mode = "Single"
# #ca_identity = {
# #  type = "SystemAssigned"
# #}
# #ca_ingress = {
# #  allow_insecure_connections = false
# #  external_enabled           = true
# #  target_port                = 3000
# #  transport                  = "auto"
# #  traffic_weight = {
# #    latest_revision = true
# #    percentage      = 100
# #  }
# #}
# #ca_container_config = {
# #  name         = "gpt-chatbot-ui"
# #  image        = "ghcr.io/pwd9000-ml/chatbot-ui:main"
# #  cpu          = 2
# #  memory       = "4Gi"
# #  min_replicas = 0
# #  max_replicas = 5

# ## Environment Variables (Required)##
# #  env = [
# #    {
# #      name        = "OPENAI_API_KEY"
# #      secret_name = "openai-api-key" #see locals.tf (Can also be added from key vault created by module, or existing key)
# #    },
# #    {
# #      name        = "OPENAI_API_HOST"
# #      secret_name = "openai-api-host" #see locals.tf (Can also be added from key vault created by module, or existing host/endpoint)
# #    },
# #    {
# #      name  = "OPENAI_API_TYPE"
# #      value = "azure"
# #    },
# #    {
# #      name  = "AZURE_DEPLOYMENT_ID" #see model_deployment variable (deployment_id)
# #      value = "gpt432k"
# #    },
# #    {
# #      name  = "DEFAULT_MODEL" #see model_deployment variable (model_name)
# #      value = "gpt-4-32k"
# #    }
# #  ]
# #}

# ### key vault access ###
# #key_vault_access_permission = ["Key Vault Secrets User"] # set to `null` to ignore permission grant to a key vault
# #key_vault_id = "kv-to-grant-permission-to" (See `data.tf`) Only required if `var.key_vault_access_permission` not `null`)

# ### CDN - Front Door ###
# create_front_door_cdn = true
# create_dns_zone       = true #Set to false if you already have a DNS zone, remember to add this DNS zone to your domain registrar

# # CDN PROFILE
# cdn_profile_name = "cdnfd"
# cdn_sku_name     = "Standard_AzureFrontDoor"

# # CDN ENDPOINTS
# cdn_endpoint = {
#   name    = "PrivateGPT"
#   enabled = true
# }

# # CDN ORIGIN GROUPS
# cdn_origin_groups = [
#   {
#     name                                                      = "PrivateGPTOriginGroup"
#     session_affinity_enabled                                  = false
#     restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 5
#     health_probe = {
#       interval_in_seconds = 100
#       path                = "/"
#       protocol            = "Https"
#       request_type        = "HEAD"
#     }
#     load_balancing = {
#       additional_latency_in_milliseconds = 50
#       sample_size                        = 4
#       successful_samples_required        = 3
#     }
#   }
# ]

# # GPT CDN ORIGIN
# cdn_gpt_origin = {
#   name                           = "PrivateGPTOrigin"
#   origin_group_name              = "PrivateGPTOriginGroup"
#   enabled                        = true
#   certificate_name_check_enabled = true
#   http_port                      = 80
#   https_port                     = 443
#   priority                       = 1
#   weight                         = 1000
# }

# # CDN ROUTE RULES
# cdn_route = {
#   name                       = "PrivateGPTRoute"
#   enabled                    = true
#   forwarding_protocol        = "HttpsOnly"
#   https_redirect_enabled     = true
#   patterns_to_match          = ["/*"]
#   supported_protocols        = ["Http", "Https"]
#   cdn_frontdoor_origin_path  = null
#   cdn_frontdoor_rule_set_ids = null
#   link_to_default_domain     = false
#   cache = {
#     query_string_caching_behavior = "IgnoreQueryString"
#     query_strings                 = []
#     compression_enabled           = false
#     content_types_to_compress     = []
#   }
# }

# # CDN WAF Config
# cdn_firewall_policy = {
#   create_waf                        = true
#   name                              = "PrivateGPTWAF"
#   enabled                           = true
#   mode                              = "Prevention"
#   custom_block_response_body        = "WW91ciByZXF1ZXN0IGhhcyBiZWVuIGJsb2NrZWQu"
#   custom_block_response_status_code = 403
#   custom_rules = [
#     {
#       name                           = "AllowedIPs"
#       action                         = "Block"
#       enabled                        = true
#       priority                       = 100
#       type                           = "MatchRule"
#       rate_limit_duration_in_minutes = 1
#       rate_limit_threshold           = 10
#       match_conditions = [
#         {
#           negation_condition = true
#           match_values       = ["86.106.76.66"] #Allowd IPs (Replace with your IP Allow list)
#           match_variable     = "RemoteAddr"
#           operator           = "IPMatch"
#           transforms         = []
#         }
#       ]
#     }
#   ]
# }

# # CDN Security Policy Config
# cdn_security_policy = {
#   name              = "PrivateGPTSecurityPolicy"
#   patterns_to_match = ["/*"]
# }