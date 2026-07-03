# Tests for the module. azurerm is mocked (no credentials, no cloud):
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}

variables {
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
  location          = "uksouth"
  workspace_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-LDO-uks-tst-001/providers/Microsoft.OperationalInsights/workspaces/LOG-ldo-uks-tst-001"
  tags              = { Environment = "tst" }
}

# The full surface: every catalog workbook, a custom workbook, and a template with the default
# Sentinel gallery, exercising the uuid derivation, lowercasing, and fallback injection.
run "full_surface" {
  command = apply

  variables {
    catalog_workbooks = {
      "incident-overview"        = {}
      "identity-signin-analysis" = { display_name = "Who is attacking us" }
      "ingestion-health"         = {}
      "detection-activity"       = {}
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
    condition     = length(azurerm_application_insights_workbook.this) == 5
    error_message = "All four catalog workbooks plus the custom one should be created."
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
    error_message = "Catalog workbooks should land in the sentinel category."
  }

  assert {
    condition     = jsondecode(azurerm_application_insights_workbook.this["incident-overview"].data_json).fallbackResourceIds[0] == lower(var.workspace_id)
    error_message = "The workspace should be injected as the fallback resource id."
  }

  assert {
    condition     = azurerm_application_insights_workbook.this["identity-signin-analysis"].display_name == "Who is attacking us"
    error_message = "A catalog display_name override should win."
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

    catalog_workbooks = { "incident-overview" = {} }
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
    condition     = length(azurerm_application_insights_workbook.this) == 1
    error_message = "The pinned workbook should be created."
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

# An unknown catalog name is rejected.
run "rejects_unknown_catalog_name" {
  command = plan

  variables {
    catalog_workbooks = { "super-secret-dashboard" = {} }
  }

  expect_failures = [var.catalog_workbooks]
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
