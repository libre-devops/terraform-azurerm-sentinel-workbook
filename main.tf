locals {
  rg = provider::azurerm::parse_resource_id(var.resource_group_id)

  # The workspace id, parsed back out of an onboarding (onboardingStates) id when given one, and
  # lowercased: the workbooks API rejects uppercase in source ids.
  workspace_id = lower(can(regex("(?i)/providers/Microsoft.SecurityInsights/onboardingStates/", var.workspace_id)) ? regex("(?i)^(.*)/providers/Microsoft\\.SecurityInsights/onboardingStates/[^/]*$", var.workspace_id)[0] : var.workspace_id)

  # Catalog workbooks rendered from the shipped JSON, with the workspace injected as the fallback
  # resource id so their queries run against the right workspace when opened.
  catalog_bodies = {
    for name, c in var.catalog_workbooks : name => jsonencode(merge(
      jsondecode(file("${path.module}/files/catalog/${name}.json")),
      { fallbackResourceIds = [local.workspace_id] }
    ))
  }

  catalog_display_names = {
    incident-overview        = "Incident operations overview"
    identity-signin-analysis = "Identity and sign-in analysis"
    ingestion-health         = "Ingestion and connector health"
    detection-activity       = "Detection and automation activity"
  }

  # Custom workbook bodies get the same fallback injection unless the caller already set one.
  custom_bodies = {
    for label, w in var.workbooks : label => jsonencode(merge(
      { fallbackResourceIds = [local.workspace_id] },
      jsondecode(w.data_json)
    ))
  }

  # One combined map drives the resource. Azure requires lowercase UUID names: derived
  # deterministically from the label so plans stay stable, overridable for adoption.
  all_workbooks = merge(
    {
      for name, c in var.catalog_workbooks : name => {
        name                 = uuidv5("url", "libre-devops/sentinel-workbook/catalog/${name}")
        display_name         = coalesce(c.display_name, local.catalog_display_names[name])
        data_json            = local.catalog_bodies[name]
        description          = null
        category             = "sentinel"
        storage_container_id = null
        tags                 = null
        identity             = null
      }
    },
    {
      for label, w in var.workbooks : label => {
        name                 = coalesce(w.name, uuidv5("url", "libre-devops/sentinel-workbook/${label}"))
        display_name         = coalesce(w.display_name, label)
        data_json            = local.custom_bodies[label]
        description          = w.description
        category             = w.category
        storage_container_id = w.storage_container_id
        tags                 = w.tags
        identity             = w.identity
      }
    },
  )
}

resource "azurerm_application_insights_workbook" "this" {
  for_each = local.all_workbooks

  resource_group_name = local.rg.resource_group_name
  location            = var.location
  tags                = merge(var.tags, coalesce(each.value.tags, {}))

  name         = each.value.name
  display_name = each.value.display_name
  data_json    = each.value.data_json
  description  = each.value.description
  category     = each.value.category
  source_id    = local.workspace_id

  storage_container_id = each.value.storage_container_id

  dynamic "identity" {
    for_each = each.value.identity != null ? [each.value.identity] : []

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }
}

resource "azurerm_application_insights_workbook_template" "this" {
  for_each = var.workbook_templates

  resource_group_name = local.rg.resource_group_name
  location            = var.location
  tags                = merge(var.tags, coalesce(each.value.tags, {}))

  name          = each.key
  template_data = each.value.template_data
  author        = each.value.author
  priority      = each.value.priority
  localized     = each.value.localized

  dynamic "galleries" {
    for_each = coalesce(each.value.galleries, [
      { category = "Libre DevOps", name = each.key, order = null, resource_type = "microsoft.securityinsightsarg/sentinel", type = "workbook" }
    ])

    content {
      category      = galleries.value.category
      name          = coalesce(galleries.value.name, each.key)
      order         = galleries.value.order
      resource_type = galleries.value.resource_type
      type          = galleries.value.type
    }
  }
}
