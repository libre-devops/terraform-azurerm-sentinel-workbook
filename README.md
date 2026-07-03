<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Sentinel Workbook

Microsoft Sentinel workbooks and gallery templates, with a curated out-of-the-box catalog.

[![CI](https://github.com/libre-devops/terraform-azurerm-sentinel-workbook/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-sentinel-workbook/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-sentinel-workbook?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-sentinel-workbook/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-sentinel-workbook)](./LICENSE)

---

## Overview

Sentinel workbooks are Azure Monitor workbooks (`Microsoft.Insights/workbooks`, behind the
misleadingly named `azurerm_application_insights_workbook` resource) with the `sentinel` category
and the workspace as their source. The raw resource wants a lowercase GUID for a name, lowercased
resource ids, and raw JSON bodies; this module handles all of that and ships useful content:

- **An out-of-the-box catalog.** Four lean, purpose-built workbooks selectable by name, each plain
  KQL against tables every workspace has: `incident-overview` (volume, severity mix, closure
  performance), `identity-signin-analysis` (who is being targeted, from where, legacy auth),
  `ingestion-health` (billable GB by table, stale tables, quiet agents), and `detection-activity`
  (alerts by rule, alert-to-incident conversion, noisy closures). The workspace is injected as
  each workbook's query target.
- **Custom workbooks without the sharp edges.** Paste the portal Advanced Editor's Gallery
  Template JSON into `data_json`: names become deterministic lowercase UUIDs derived from your
  label (stable plans, `name` override for adoption), the source id is lowercased as the API
  demands, the category defaults to `sentinel`, and a check flags bodies exported from a
  different workspace (they would silently query the wrong place).
- **Gallery templates.** `workbook_templates` land in the workbook gallery's Templates tab for
  self-serve instantiation, defaulting into the Sentinel gallery
  (`microsoft.securityinsightsarg/sentinel`).
- **Bring-your-own-storage supported.** `storage_container_id` and an identity travel together
  (validated: one without the other is always a mistake).
- **Explicit onboarding dependency.** `workspace_id` accepts the sentinel module's
  `onboarding_id` (or a plain workspace id) and parses the workspace id back out of it.

Requires Terraform >= 1.9 and azurerm >= 4.0. Pairs with
[`libre-devops/sentinel/azurerm`](https://registry.terraform.io/modules/libre-devops/sentinel/azurerm/latest),
which owns the workspace onboarding.

## Usage

```hcl
module "sentinel" {
  source  = "libre-devops/sentinel/azurerm"
  version = "~> 4.0"

  workspace_id = module.log_analytics.workspace_ids["log-ldo-uks-prd-001"]
}

module "sentinel_workbook" {
  source  = "libre-devops/sentinel-workbook/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids["rg-ldo-uks-prd-001"]
  location          = "uksouth"
  tags              = module.tags.tags

  workspace_id = module.sentinel.onboarding_id

  catalog_workbooks = {
    "incident-overview" = {}
    "ingestion-health"  = {}
  }

  workbooks = {
    "our-soc-dashboard" = {
      data_json = file("${path.module}/workbooks/soc-dashboard.json")
    }
  }
}
```

## Examples

- [`examples/minimal`](./examples/minimal) - the incident operations workbook on a freshly
  onboarded workspace.
- [`examples/complete`](./examples/complete) - the whole catalog, a custom workbook from inline
  JSON, and a gallery template in the Sentinel Templates tab, with bring-your-own-storage shown
  gated off.

## Developing

Local work needs **PowerShell 7+** and **[`just`](https://github.com/casey/just)**, because the recipes
wrap the [LibreDevOpsHelpers](https://www.powershellgallery.com/packages/LibreDevOpsHelpers)
PowerShell module (the same engine the `libre-devops/terraform-azure` action runs in CI). Install
just with `brew install just`, or `uv tool add rust-just` then `uv run just <recipe>`.

Run `just` to list recipes: `just update-ldo-pwsh` (install or force-update LibreDevOpsHelpers from
PSGallery), `just validate`, `just scan` (Trivy only), `just pwsh-analyze` (PSScriptAnalyzer only),
`just plan`, `just apply`, `just destroy`, `just e2e`, `just test`, and `just docs` (the
plan/apply/destroy recipes mirror the action, including the storage firewall dance; `just e2e`
applies an example then always destroys it, defaulting to `minimal`, so nothing is left running).
Releasing is also `just`:
`just increment-release [patch|minor|major]` bumps, tags, and publishes a GitHub release, and the
Terraform Registry picks up the tag.

## Security scan exceptions

This module is scanned with [Trivy](https://github.com/aquasecurity/trivy); HIGH and CRITICAL
findings fail the build. Any waiver is a deliberate, reviewed decision, never a way to quiet a
finding that should be fixed. Waivers live in a `.trivyignore.yaml` (the machine-applied source of
truth, passed to Trivy with `--ignorefile`) and are mirrored in a table here so the reason is
auditable.

There are currently **no exceptions**: the module and its examples scan clean.

## Reference

The Requirements, Providers, Inputs, Outputs, and Resources below are generated by `terraform-docs`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_application_insights_workbook.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights_workbook) | resource |
| [azurerm_application_insights_workbook_template.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights_workbook_template) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_catalog_workbooks"></a> [catalog\_workbooks](#input\_catalog\_workbooks) | Out-of-the-box workbooks shipped with the module, keyed by catalog name, deployed as saved<br/>workbooks against the workspace. Set an entry to {} for the defaults or override display\_name.<br/>Available: incident-overview (volume, severity mix, closure performance),<br/>identity-signin-analysis (failed sign-in pressure, needs the Entra ID connector),<br/>ingestion-health (billable volume by table, stale tables, quiet agents), and detection-activity<br/>(alerts by rule, alert-to-incident conversion, noisy closures). | <pre>map(object({<br/>    display_name = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | The Azure region the workbooks live in. | `string` | n/a | yes |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | The id of the resource group the workbooks land in (workbooks are Microsoft.Insights resources, resource group scoped). Parsed for the resource group name. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every workbook and template (merged with any per-item tags). | `map(string)` | `{}` | no |
| <a name="input_workbook_templates"></a> [workbook\_templates](#input\_workbook\_templates) | Workbook gallery templates keyed by a label. Templates appear in the workbook gallery's Templates<br/>tab for self-serve instantiation instead of cluttering saved workbooks. template\_data is the<br/>template JSON; galleries defaults to the Sentinel workbook gallery<br/>(microsoft.securityinsightsarg/sentinel) under the given category. | <pre>map(object({<br/>    template_data = string<br/><br/>    author    = optional(string)<br/>    priority  = optional(number)<br/>    localized = optional(string)<br/>    tags      = optional(map(string))<br/><br/>    galleries = optional(list(object({<br/>      category      = string<br/>      name          = optional(string)<br/>      order         = optional(number)<br/>      resource_type = optional(string, "microsoft.securityinsightsarg/sentinel")<br/>      type          = optional(string, "workbook")<br/>    })))<br/>  }))</pre> | `{}` | no |
| <a name="input_workbooks"></a> [workbooks](#input\_workbooks) | Custom workbooks keyed by a label that doubles as the display name unless display\_name is set.<br/>data\_json is the workbook body (the JSON from the portal's Advanced Editor, "Gallery Template"<br/>format); the module injects the workspace as the fallback resource id unless the body already<br/>carries one. Azure requires the resource name to be a lowercase UUID: the module derives a<br/>deterministic one from the label (uuidv5); set name to adopt an existing workbook. category<br/>defaults to sentinel so the workbook lands in the Sentinel gallery.<br/><br/>storage\_container\_id (bring-your-own storage for the workbook content) requires an identity with<br/>data-plane rights on the container, and the two must travel together. | <pre>map(object({<br/>    data_json = string<br/><br/>    name                 = optional(string)<br/>    display_name         = optional(string)<br/>    description          = optional(string)<br/>    category             = optional(string, "sentinel")<br/>    storage_container_id = optional(string)<br/>    tags                 = optional(map(string))<br/><br/>    identity = optional(object({<br/>      type         = string<br/>      identity_ids = optional(list(string))<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_workspace_id"></a> [workspace\_id](#input\_workspace\_id) | The Sentinel workspace the workbooks belong to. Accepts either the Log Analytics workspace id or<br/>the sentinel module's onboarding\_id (an onboardingStates id): the workspace id is parsed back out<br/>of it. It becomes each workbook's source (lowercased, as the API demands) so they appear in the<br/>workspace's Sentinel workbook gallery, and it is injected as the fallback resource id so catalog<br/>queries run against the right workspace. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_workbook_ids"></a> [workbook\_ids](#output\_workbook\_ids) | Map of workbook label to its id. |
| <a name="output_workbook_ids_zipmap"></a> [workbook\_ids\_zipmap](#output\_workbook\_ids\_zipmap) | Map of workbook label to { name, id }, for easy composition with other modules (metadata parent\_id, for example). |
| <a name="output_workbook_names"></a> [workbook\_names](#output\_workbook\_names) | Map of workbook label to the workbook's UUID name (deterministic unless overridden). |
| <a name="output_workbook_template_ids"></a> [workbook\_template\_ids](#output\_workbook\_template\_ids) | Map of template label to its id. |
| <a name="output_workbook_template_ids_zipmap"></a> [workbook\_template\_ids\_zipmap](#output\_workbook\_template\_ids\_zipmap) | Map of template label to { name, id }, for easy composition with other modules. |
| <a name="output_workbook_templates"></a> [workbook\_templates](#output\_workbook\_templates) | Map of template label to the full workbook template object. |
| <a name="output_workbooks"></a> [workbooks](#output\_workbooks) | Map of workbook label (catalog and custom) to the full workbook object. |
| <a name="output_workspace_id"></a> [workspace\_id](#output\_workspace\_id) | The Log Analytics workspace id the workbooks are pinned to (parsed from an onboarding id when one was given, lowercased). |
<!-- END_TF_DOCS -->
