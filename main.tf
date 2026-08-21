# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    project = "advanced-security-solutions"
    purpose = "portfolio-demo"
  }
}

# ---------------------------------------------------------------------------
# Log Analytics Workspace (required backing store for Microsoft Sentinel)
# Daily ingestion cap keeps this near-free even if noisy data connectors
# are added later.
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                = var.workspace_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  daily_quota_gb      = var.daily_ingestion_cap_gb

  tags = {
    project = "advanced-security-solutions"
  }
}

# ---------------------------------------------------------------------------
# Microsoft Sentinel — onboard it onto the Log Analytics workspace
# ---------------------------------------------------------------------------
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id = azurerm_log_analytics_workspace.law.id
}

# ---------------------------------------------------------------------------
# Microsoft Defender for Cloud — explicitly pinned to Free tier.
# This prevents Terraform (or anyone) from silently defaulting to a paid
# plan, which is the most common source of surprise Defender costs.
# ---------------------------------------------------------------------------
resource "azurerm_security_center_subscription_pricing" "defender_vms" {
  tier          = "Free"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "defender_storage" {
  tier          = "Free"
  resource_type = "StorageAccounts"
}

resource "azurerm_security_center_subscription_pricing" "defender_keyvaults" {
  tier          = "Free"
  resource_type = "KeyVaults"
}

# ---------------------------------------------------------------------------
# Connect Defender for Cloud's security alerts into Sentinel.
# This connector streams ALERTS (not raw logs), so it does not count
# against the Log Analytics ingestion cap or add meaningful cost.
# ---------------------------------------------------------------------------
resource "azurerm_sentinel_data_connector_azure_security_center" "asc_connector" {
  name                       = "defender-for-cloud-connector"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]
}

# ---------------------------------------------------------------------------
# Key Vault — for managing secrets/keys referenced by security tooling.
# Soft-delete is enabled by default (Azure requirement); purge protection
# is left OFF so the vault can be fully destroyed during teardown.
# ---------------------------------------------------------------------------
resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "kv" {
  name                        = "kv-advsec-${random_string.kv_suffix.result}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
  soft_delete_retention_days  = 7

  tags = {
    project = "advanced-security-solutions"
  }
}

resource "azurerm_key_vault_access_policy" "me" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Purge", "Recover"
  ]
}

resource "azurerm_key_vault_secret" "demo_secret" {
  name         = "demo-api-key"
  value        = "placeholder-value-replace-me"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault_access_policy.me]
}
