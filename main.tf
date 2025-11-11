terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.17.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}



# Create Resource Group
resource "azurerm_resource_group" "openai_rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Create Cognitive Services Account
resource "azurerm_cognitive_account" "openai" {
  name                = var.account_name
  location            = var.location
  resource_group_name = azurerm_resource_group.openai_rg.name
  kind                = "OpenAI"
  sku_name            = var.sku_name
  tags                = var.tags
}

# Create RAI Policies with content filters
# Create RAI Policies with content filters
resource "azurerm_cognitive_account_rai_policy" "content_filters" {
  for_each = local.all_filters

  name                 = each.value.name
  cognitive_account_id = azurerm_cognitive_account.openai.id
  base_policy_name     = "Microsoft.Default"
  mode                 = each.value.mode

  dynamic "content_filter" {
    for_each = lookup(local.all_filters[each.key], "filters", [])
    content {
      name               = lookup(content_filter.value, "name", "")
      filter_enabled     = true
      block_enabled      = true
      severity_threshold = lookup(content_filter.value, "severity_threshold", "Medium")
      source             = lookup(content_filter.value, "source", "Prompt")
    }
  }

  depends_on = [azurerm_cognitive_account.openai]
}


# Create custom blocklists only when specified
resource "null_resource" "create_custom_blocklists" {
  count = length(compact(flatten([
    for cf in local.all_filters : [
      for bl in try(cf.blocklists, []) : bl.name
    ]
  ]))) > 0 ? 1 : 0

  triggers = {
    always_run = timestamp()
    blocklists_json = jsonencode(flatten([
      for cf in local.all_filters : [
        for bl in try(cf.blocklists, []) : {
          name        = bl.name
          description = try(bl.description, "")
          items       = try(bl.items, [])
        }
      ]
    ]))
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/create_blocklist_new.py"
    environment = {
      SUBSCRIPTION_ID      = var.subscription_id
      RESOURCE_GROUP_NAME  = var.resource_group_name
      ACCOUNT_NAME         = var.account_name
      BLOCKLISTS_JSON      = self.triggers.blocklists_json
    }
  }

  depends_on = [azurerm_cognitive_account_rai_policy.content_filters]
}

resource "null_resource" "apply_blocklists" {
  for_each = { for idx, cf in local.all_filters : idx => cf }

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/apply_blocklist_new.py"
    environment = {
      SUBSCRIPTION_ID     = var.subscription_id
      RESOURCE_GROUP_NAME = var.resource_group_name
      ACCOUNT_NAME        = var.account_name
      CONTENT_FILTER_NAME = each.value.name
      BLOCKLIST_NAMES     = join(",", compact([
        for bl in try(each.value.blocklists, []) : bl.name
      ]))
    }
  }

  depends_on = [null_resource.create_custom_blocklists]
}

# Delete any Azure blocklists that are not in Terraform
resource "null_resource" "delete_unused_blocklists" {
  count = length(compact(flatten([
    for cf in local.all_filters : [
      for bl in try(cf.blocklists, []) : bl.name
    ]
  ]))) > 0 ? 1 : 0

  triggers = {
    always_run       = timestamp()
    blocklists_names = join(",", flatten([
      for cf in local.all_filters : [
        for bl in try(cf.blocklists, []) : bl.name
      ]
    ]))
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/delete_unused_blocklists.py"
    environment = {
      SUBSCRIPTION_ID     = var.subscription_id
      RESOURCE_GROUP_NAME = var.resource_group_name
      ACCOUNT_NAME        = var.account_name
      BLOCKLISTS_NAMES    = self.triggers.blocklists_names
    }
  }

  depends_on = [null_resource.apply_blocklists]
}
