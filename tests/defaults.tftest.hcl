# Tests for the module. azurerm is mocked (no credentials, no cloud):
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}
mock_provider "azapi" {}

variables {
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
  location          = "uksouth"
  workspace_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-LDO-uks-tst-001/providers/Microsoft.OperationalInsights/workspaces/LOG-ldo-uks-tst-001"
  tags              = { Environment = "tst" }
}

# The default call ships the whole baseline for free.
run "baseline_by_default" {
  command = apply

  assert {
    condition     = length(azurerm_application_insights_workbook.this) == 4
    error_message = "The full baseline should deploy with no configuration."
  }

  assert {
    condition     = azurerm_application_insights_workbook.this["incident-overview"].display_name == "Incident operations overview"
    error_message = "Baseline workbooks should carry their curated display names."
  }
}

# create_example_incidents seeds the labelled demo set; off by default.
run "example_incidents_opt_in" {
  command = apply

  variables {
    create_example_incidents = true
  }

  assert {
    condition     = length(azapi_resource.example_incident) == 6
    error_message = "All six example incidents should be created when opted in."
  }

  assert {
    condition     = alltrue([for i in values(azapi_resource.example_incident) : startswith(i.body.properties.title, "[Example]")])
    error_message = "Every example incident title should carry the [Example] prefix."
  }

  assert {
    condition     = azapi_resource.example_incident["example-phishing"].body.properties.classification == "BenignPositive"
    error_message = "Closed example incidents should carry their classification."
  }

  assert {
    condition     = !can(azapi_resource.example_incident["example-bruteforce"].body.properties.classification)
    error_message = "Open example incidents should not carry classification fields."
  }
}

# No incidents unless asked for.
run "no_example_incidents_by_default" {
  command = apply

  assert {
    condition     = length(azapi_resource.example_incident) == 0
    error_message = "Example incidents are strictly opt-in."
  }
}

# baseline_enabled = false turns the whole set off.
run "baseline_opt_out" {
  command = apply

  variables {
    baseline_enabled = false
  }

  assert {
    condition     = length(azurerm_application_insights_workbook.this) == 0
    error_message = "Disabling the baseline should deploy nothing."
  }
}

# The full surface: the baseline with overrides (one disabled, one renamed and recategorized), a
# custom workbook, and a template with the default Sentinel gallery, exercising the uuid
# derivation, lowercasing, and fallback injection.
run "full_surface" {
  command = apply

  variables {
    baseline_overrides = {
      "identity-signin-analysis" = { display_name = "Who is attacking us", category = "workbook", tags = { Component = "identity" } }
      "detection-activity"       = { enabled = false }
    }

    workbooks = {
      "kv-audit" = {
        data_json   = jsonencode({ version = "Notebook/1.0", items = [] })
        description = "Key Vault data-plane audit."
        tags        = { Component = "kv" }
      }
    }

    workbook_templates = {
      "ldo-baseline" = {
        template_data = jsonencode({ version = "Notebook/1.0", items = [] })
        author        = "Libre DevOps"
        priority      = 1
      }
    }
  }

  assert {
    condition     = length(azurerm_application_insights_workbook.this) == 4
    error_message = "Three baseline workbooks (one disabled) plus the custom one should be created."
  }

  assert {
    condition     = !contains(keys(azurerm_application_insights_workbook.this), "detection-activity")
    error_message = "A disabled baseline workbook should not be created."
  }

  assert {
    condition     = azurerm_application_insights_workbook.this["identity-signin-analysis"].category == "workbook" && azurerm_application_insights_workbook.this["identity-signin-analysis"].tags["Component"] == "identity"
    error_message = "Baseline overrides should tune category and tags."
  }

  assert {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", azurerm_application_insights_workbook.this["incident-overview"].name))
    error_message = "Workbook names should be deterministic lowercase UUIDs."
  }

  assert {
    condition     = azurerm_application_insights_workbook.this["incident-overview"].source_id == lower(var.workspace_id)
    error_message = "The workspace source id should be lowercased (the API rejects uppercase)."
  }

  assert {
    condition     = azurerm_application_insights_workbook.this["incident-overview"].category == "sentinel"
    error_message = "Baseline workbooks should land in the sentinel category."
  }

  assert {
    condition     = jsondecode(azurerm_application_insights_workbook.this["incident-overview"].data_json).fallbackResourceIds[0] == lower(var.workspace_id)
    error_message = "The workspace should be injected as the fallback resource id."
  }

  assert {
    condition     = azurerm_application_insights_workbook.this["identity-signin-analysis"].display_name == "Who is attacking us"
    error_message = "A baseline display_name override should win."
  }

  assert {
    condition     = azurerm_application_insights_workbook.this["kv-audit"].display_name == "kv-audit"
    error_message = "A custom workbook's display name should default to its label."
  }

  assert {
    condition     = jsondecode(azurerm_application_insights_workbook.this["kv-audit"].data_json).fallbackResourceIds[0] == lower(var.workspace_id)
    error_message = "Custom bodies should get the fallback workspace injected too."
  }

  assert {
    condition     = azurerm_application_insights_workbook_template.this["ldo-baseline"].galleries[0].resource_type == "microsoft.securityinsightsarg/sentinel"
    error_message = "Templates should default into the Sentinel workbook gallery."
  }
}

# An onboarding (onboardingStates) id is accepted and parsed back to the workspace id.
run "parses_onboarding_id" {
  command = apply

  variables {
    workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.OperationalInsights/workspaces/log-ldo-uks-tst-001/providers/Microsoft.SecurityInsights/onboardingStates/default"
  }

  assert {
    condition     = azurerm_application_insights_workbook.this["incident-overview"].source_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/rg-ldo-uks-tst-001/providers/microsoft.operationalinsights/workspaces/log-ldo-uks-tst-001"
    error_message = "The workspace id should be parsed out of the onboarding id and lowercased."
  }
}

# A custom body already pinned to this workspace passes the fallback check.
run "accepts_matching_fallback" {
  command = apply

  variables {
    workbooks = {
      "pinned" = {
        data_json = jsonencode({
          version             = "Notebook/1.0"
          items               = []
          fallbackResourceIds = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/rg-ldo-uks-tst-001/providers/microsoft.operationalinsights/workspaces/log-ldo-uks-tst-001"]
        })
      }
    }
  }

  assert {
    condition     = length(azurerm_application_insights_workbook.this) == 5
    error_message = "The pinned workbook should be created alongside the baseline."
  }
}

# A body exported from another workspace trips the wrong-workspace check.
run "flags_foreign_fallback" {
  command = apply

  variables {
    workbooks = {
      "foreign" = {
        data_json = jsonencode({
          version             = "Notebook/1.0"
          items               = []
          fallbackResourceIds = ["/subscriptions/99999999-9999-9999-9999-999999999999/resourcegroups/rg-other/providers/microsoft.operationalinsights/workspaces/log-other"]
        })
      }
    }
  }

  expect_failures = [check.custom_bodies_target_this_workspace]
}

# An unknown baseline override key is rejected.
run "rejects_unknown_baseline_key" {
  command = plan

  variables {
    baseline_overrides = { "super-secret-dashboard" = {} }
  }

  expect_failures = [var.baseline_overrides]
}

# Malformed workbook JSON is rejected.
run "rejects_bad_json" {
  command = plan

  variables {
    workbooks = {
      bad = { data_json = "{not json" }
    }
  }

  expect_failures = [var.workbooks]
}

# Storage without an identity (and the reverse) is rejected.
run "rejects_storage_without_identity" {
  command = plan

  variables {
    workbooks = {
      bad = {
        data_json            = "{}"
        storage_container_id = "https://stldoukstst001.blob.core.windows.net/workbooks"
      }
    }
  }

  expect_failures = [var.workbooks]
}

# An uppercase or malformed explicit name is rejected.
run "rejects_bad_explicit_name" {
  command = plan

  variables {
    workbooks = {
      bad = { data_json = "{}", name = "NOT-A-GUID" }
    }
  }

  expect_failures = [var.workbooks]
}

# A workspace_id that is neither shape is rejected.
run "rejects_wrong_workspace_id" {
  command = plan

  variables {
    workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-x/providers/Microsoft.KeyVault/vaults/kv-x"
  }

  expect_failures = [var.workspace_id]
}
