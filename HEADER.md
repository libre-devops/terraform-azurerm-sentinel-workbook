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

- **A baseline you get for free.** Calling the module deploys four purpose-built SOC workbooks by
  default, the same shape as the policy module's baseline: `incident-overview` (KPI tiles,
  severity and ownership mix, triage and closure performance, aging incidents),
  `identity-signin-analysis` (failure reasons, targeted accounts, attacking IPs, legacy auth,
  Entra risk events), `ingestion-health` (billable volume, ingestion anomaly detection, stale
  tables, quiet agents), and `detection-activity` (rule noise, MITRE tactic coverage,
  alert-to-incident conversion, tuning candidates). Every panel honours a shared time range
  parameter, grids carry severity icons and heatmaps, and the workspace is injected as each
  workbook's query target. Tune or drop individual ones through `baseline_overrides`; turn the
  set off with `baseline_enabled = false`.
- **See them in full flow.** `create_example_incidents = true` seeds six clearly labelled
  incidents through the Sentinel incidents API (plain ARM via azapi, no logic app): all
  severities, open and unassigned states, and classified noise closures, so the incident and
  detection panels render with data on a fresh workspace. Off by default; destroy removes them.
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

Requires Terraform >= 1.9, azurerm >= 4.0, and azapi >= 2.0 (the incident seeding). Pairs with
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

  # The baseline deploys by itself; tune it rather than define it.
  baseline_overrides = {
    "identity-signin-analysis" = { display_name = "Identity attack surface" }
  }

  workbooks = {
    "our-soc-dashboard" = {
      data_json = file("${path.module}/workbooks/soc-dashboard.json")
    }
  }
}
```

## Examples

- [`examples/minimal`](./examples/minimal) - nothing but placement: the baseline arrives free on
  a freshly onboarded workspace.
- [`examples/complete`](./examples/complete) - the baseline tuned through overrides, a custom
  workbook from inline JSON, a gallery template in the Sentinel Templates tab, and the example
  incidents seeded so everything renders in full flow.

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
