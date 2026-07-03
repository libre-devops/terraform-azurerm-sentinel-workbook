locals {
  rg = provider::azurerm::parse_resource_id(var.resource_group_id)

  # The workspace id, parsed back out of an onboarding (onboardingStates) id when given one. Two
  # casings on purpose: azapi round-trips the ARM-canonical casing into state (lowercasing it
  # would force perpetual replacement of the incidents), while the workbooks API rejects
  # uppercase in source ids.
  workspace_id_raw = can(regex("(?i)/providers/Microsoft.SecurityInsights/onboardingStates/", var.workspace_id)) ? regex("(?i)^(.*)/providers/Microsoft\\.SecurityInsights/onboardingStates/[^/]*$", var.workspace_id)[0] : var.workspace_id
  workspace_id     = lower(local.workspace_id_raw)

  baseline_display_names = {
    incident-overview        = "Incident operations overview"
    identity-signin-analysis = "Identity and sign-in analysis"
    ingestion-health         = "Ingestion and connector health"
    detection-activity       = "Detection and automation activity"
  }

  # The baseline set: every curated workbook unless the whole baseline is off or an override
  # disables one. Overrides tune display name, category, and tags; content stays curated.
  baseline_set = {
    for name in keys(local.baseline_display_names) : name => lookup(var.baseline_overrides, name, {
      enabled      = true
      display_name = null
      category     = null
      tags         = null
    }) if var.baseline_enabled && try(lookup(var.baseline_overrides, name, null).enabled, true)
  }

  # Baseline bodies rendered from the shipped JSON, with the workspace injected as the fallback
  # resource id so their queries run against the right workspace when opened.
  baseline_bodies = {
    for name, c in local.baseline_set : name => jsonencode(merge(
      jsondecode(file("${path.module}/files/catalog/${name}.json")),
      { fallbackResourceIds = [local.workspace_id] }
    ))
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
      for name, c in local.baseline_set : name => {
        name                 = uuidv5("url", "libre-devops/sentinel-workbook/catalog/${name}")
        display_name         = coalesce(c.display_name, local.baseline_display_names[name])
        data_json            = local.baseline_bodies[name]
        description          = null
        category             = coalesce(c.category, "sentinel")
        storage_container_id = null
        tags                 = c.tags
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

# Example incidents: the Sentinel incidents API is plain ARM, so azapi creates them directly (no
# logic app, no raw HTTP), and destroy removes them. The mix exercises the incident-overview and
# detection-activity panels: severities, open and aging states, an unassigned incident, and a
# noise closure that feeds the tuning-candidates grid.
locals {
  # Every entry carries the full shape (nulls where unused) and the gate rides through a filtered
  # for instead of a ternary: conditional branches must unify types.
  example_incidents = merge([for set in [{
    "example-bruteforce" = {
      title                  = "[Example] Brute force attack against a privileged account"
      severity               = "High"
      status                 = "Active"
      description            = "Example incident seeded by terraform-azurerm-sentinel-workbook so the baseline workbooks render with data. Safe to close or delete."
      classification         = null
      classification_reason  = null
      classification_comment = null
    }
    "example-impossible-travel" = {
      title                  = "[Example] Impossible travel for user account"
      severity               = "High"
      status                 = "New"
      description            = "Example incident seeded by terraform-azurerm-sentinel-workbook. Deliberately unassigned so the new-and-unassigned KPI registers."
      classification         = null
      classification_reason  = null
      classification_comment = null
    }
    "example-malware" = {
      title                  = "[Example] Malware detected on workstation"
      severity               = "Medium"
      status                 = "Active"
      description            = "Example incident seeded by terraform-azurerm-sentinel-workbook. Safe to close or delete."
      classification         = null
      classification_reason  = null
      classification_comment = null
    }
    "example-phishing" = {
      title                  = "[Example] Phishing email reported by user"
      severity               = "Medium"
      status                 = "Closed"
      description            = "Example incident seeded by terraform-azurerm-sentinel-workbook, closed as expected noise so the closure and tuning panels register."
      classification         = "BenignPositive"
      classification_reason  = "SuspiciousButExpected"
      classification_comment = "Simulated phishing exercise."
    }
    "example-scanner" = {
      title                  = "[Example] Vulnerability scanner traffic flagged"
      severity               = "Low"
      status                 = "Closed"
      description            = "Example incident seeded by terraform-azurerm-sentinel-workbook, closed as a false positive."
      classification         = "FalsePositive"
      classification_reason  = "InaccurateData"
      classification_comment = "Known scanner appliance."
    }
    "example-legacy-auth" = {
      title                  = "[Example] Legacy authentication attempt observed"
      severity               = "Informational"
      status                 = "New"
      description            = "Example incident seeded by terraform-azurerm-sentinel-workbook. Safe to close or delete."
      classification         = null
      classification_reason  = null
      classification_comment = null
    }
  }] : set if var.create_example_incidents]...)
}

resource "azapi_resource" "example_incident" {
  for_each = local.example_incidents

  type      = "Microsoft.SecurityInsights/incidents@2024-03-01"
  name      = uuidv5("url", "libre-devops/sentinel-workbook/incident/${each.key}")
  parent_id = local.workspace_id_raw

  body = {
    properties = merge(
      {
        title       = each.value.title
        severity    = each.value.severity
        status      = each.value.status
        description = each.value.description
      },
      each.value.status == "Closed" ? {
        classification        = each.value.classification
        classificationReason  = each.value.classification_reason
        classificationComment = each.value.classification_comment
      } : {},
    )
  }

  # The service stamps bookkeeping properties (incident number, URLs, timestamps) onto the
  # resource after create; azapi only tracks the configured body, so no ignore_changes needed.
  schema_validation_enabled = false
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
