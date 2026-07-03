# Every feature of the module: the full out-of-the-box catalog (with a display name override), a
# custom workbook from inline JSON, and a gallery template landing in the Sentinel Templates tab.
# Bring-your-own-storage workbooks are shown gated off: they need a storage container plus an
# identity with data-plane rights, a deployment decision rather than an example default.
# Applied then destroyed in one CI run.
locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  law_name = "log-${var.short}-${var.loc}-${terraform.workspace}-002"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-sentinel-workbook" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "log_analytics" {
  source  = "libre-devops/log-analytics-workspace/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  log_analytics_workspaces = { (local.law_name) = {} }
}

module "sentinel" {
  source  = "libre-devops/sentinel/azurerm"
  version = "~> 4.0"

  workspace_id = module.log_analytics.workspace_ids[local.law_name]
}

module "sentinel_workbook" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  workspace_id = module.sentinel.onboarding_id

  # The whole out-of-the-box catalog: incident operations, identity pressure, ingestion health,
  # and detection activity, each a lean KQL workbook against tables every workspace has.
  catalog_workbooks = {
    "incident-overview"        = {}
    "identity-signin-analysis" = { display_name = "Identity attack surface" }
    "ingestion-health"         = {}
    "detection-activity"       = {}
  }

  # A custom workbook from inline JSON (paste the portal Advanced Editor's Gallery Template JSON
  # into data_json, or file() it); the module injects this workspace as the query target.
  workbooks = {
    "watchlist-coverage" = {
      description = "Which watchlists exist and how fresh their items are."

      data_json = jsonencode({
        version = "Notebook/1.0"
        items = [
          {
            type    = 1
            content = { json = "## Watchlist coverage\n---\nWatchlists in this workspace and their item freshness." }
            name    = "header"
          },
          {
            type = 3
            content = {
              version       = "KqlItem/1.0"
              query         = "_GetWatchlistAlias\n| extend Alias = tostring(WatchlistAlias)\n| join kind=leftouter (Watchlist | summarize Items = count(), LastUpdated = max(LastUpdatedTimeUTC) by WatchlistAlias) on $left.Alias == $right.WatchlistAlias\n| project Alias, Items = coalesce(Items, 0), LastUpdated"
              size          = 0
              title         = "Watchlists and item freshness"
              timeContext   = { durationMs = 604800000 }
              queryType     = 0
              resourceType  = "microsoft.operationalinsights/workspaces"
              visualization = "table"
            }
            name = "watchlists"
          },
        ]
        "$schema" = "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
      })

      tags = { Component = "watchlists" }
    }
  }

  # A gallery template: appears in Sentinel's workbook Templates tab (self-serve, instantiated on
  # demand) instead of the saved list.
  workbook_templates = {
    "ldo-incident-overview-template" = {
      author   = "Libre DevOps"
      priority = 1

      template_data = file("${path.module}/../../files/catalog/incident-overview.json")

      galleries = [
        {
          category      = "Libre DevOps"
          name          = "Incident operations overview"
          order         = 100
          resource_type = "microsoft.securityinsightsarg/sentinel"
          type          = "workbook"
        }
      ]
    }
  }
}
