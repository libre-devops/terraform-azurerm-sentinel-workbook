<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

Every feature of the module. A CSV file watchlist exercising the full attribute surface (display
name, ISO8601 retention, description, labels), an inline CSV with deliberately messy spacing that
the trim pipeline cleans on import, and a native-items watchlist, all wired through the sentinel
module's onboarding_id so the onboarding ordering is explicit. Run it with `just e2e complete`,
which applies the stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
# Every feature of the module: the free baseline tuned through overrides (one renamed, one
# recategorized), a custom workbook from inline JSON, a gallery template landing in the Sentinel
# Templates tab, and the example incidents seeded through the Sentinel incidents API so the
# workbooks render in full flow instead of empty panels. Bring-your-own-storage workbooks are a
# deployment decision (storage container plus an identity with data-plane rights) rather than an
# example default. Applied then destroyed in one CI run.
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

  # The baseline deploys by itself; overrides tune it without touching the curated content.
  baseline_overrides = {
    "identity-signin-analysis" = { display_name = "Identity attack surface" }
    "ingestion-health"         = { tags = { Component = "finops" } }
  }

  # Seed the labelled example incidents (via the Sentinel incidents API, no logic app) so the
  # incident and detection panels render with data; destroy removes them with the stack.
  create_example_incidents = true

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
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | >= 2.0.0, < 3.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0, < 4.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_log_analytics"></a> [log\_analytics](#module\_log\_analytics) | libre-devops/log-analytics-workspace/azurerm | ~> 4.0 |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_sentinel"></a> [sentinel](#module\_sentinel) | libre-devops/sentinel/azurerm | ~> 4.0 |
| <a name="module_sentinel_workbook"></a> [sentinel\_workbook](#module\_sentinel\_workbook) | ../../ | n/a |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_workbook_ids_zipmap"></a> [workbook\_ids\_zipmap](#output\_workbook\_ids\_zipmap) | Map of workbook label to { name, id } (feed metadata parent\_id from this). |
| <a name="output_workbook_template_ids"></a> [workbook\_template\_ids](#output\_workbook\_template\_ids) | Map of template label to id. |
<!-- END_TF_DOCS -->
