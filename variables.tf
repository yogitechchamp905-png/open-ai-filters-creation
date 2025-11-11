variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "account_name" {
  description = "Name of the Cognitive Services account"
  type        = string
}

variable "sku_name" {
  description = "SKU for the Cognitive Services account"
  type        = string
  default     = "S0"
}

variable "policy_name" {
  description = "Name of the RAI policy"
  type        = string
  default     = "standard-content-policy"
}

variable "blocklist_name" {
  description = "Name of the blocklist to create"
  type        = string
  default = "Profanity"
}

variable "blocklist_description" {
  description = "Description for the blocklist"
  type        = string
  default     = "Managed by Terraform"
}

variable "content_filters" {
  description = "List of content filter configurations for Azure OpenAI RAI policy."
  type = list(object({
    name        = string
    mode        = string
    filters     = list(object({
      name               = string
      severity_threshold = string
      source             = string
    }))
    blocklists = optional(list(object({
      name        = string
      description = optional(string)
      items = list(object({
        pattern     = string
        description = optional(string)
      }))
    })), [])
  }))
  default = []
  validation {
    condition = alltrue(flatten([
      # Validate mode (streaming_mode)
      [
        for _, policy in var.content_filters :
        contains(["asynchronous_filter", "default"], lower(policy.mode))
      ],

      # Validate filter severity thresholds if defined
      [
        for _, policy in var.content_filters :
        alltrue([
          for _, f in coalesce(policy.filters, []) :
          (
            can(f.severity_threshold) &&
            contains(["low", "medium"], lower(f.severity_threshold))
          )
        ])
      ]
    ]))
    error_message = "Invalid configuration: 'mode' must be one of ['Asynchronous_filter', 'Default'], and if defined, 'severity_threshold' must be 'Low' or 'Medium' (case-insensitive)."
  }
}


variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {
    environment = "production"
    managed_by  = "terraform"
  }
}


