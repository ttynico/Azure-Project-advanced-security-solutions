variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-advanced-security-demo"
}

variable "workspace_name" {
  description = "Log Analytics workspace name (Sentinel's backing workspace)"
  type        = string
  default     = "law-advsec-demo"
}

variable "daily_ingestion_cap_gb" {
  description = "Daily ingestion cap in GB to keep Sentinel/Log Analytics costs near-zero"
  type        = number
  default     = 0.5
}

variable "log_retention_days" {
  description = "Log Analytics retention period in days"
  type        = number
  default     = 30
}
