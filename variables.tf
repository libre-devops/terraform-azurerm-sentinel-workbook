variable "catalog_workbooks" {
  description = <<DESC
Out-of-the-box workbooks shipped with the module, keyed by catalog name, deployed as saved
workbooks against the workspace. Set an entry to {} for the defaults or override display_name.
Available: incident-overview (volume, severity mix, closure performance),
identity-signin-analysis (failed sign-in pressure, needs the Entra ID connector),
ingestion-health (billable volume by table, stale tables, quiet agents), and detection-activity
(alerts by rule, alert-to-incident conversion, noisy closures).
DESC

  type = map(object({
    display_name = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for name in keys(var.catalog_workbooks) : contains(["incident-overview", "identity-signin-analysis", "ingestion-health", "detection-activity"], name)])
    error_message = "catalog_workbooks keys must be catalog names: incident-overview, identity-signin-analysis, ingestion-health, detection-activity."
  }
}

variable "location" {
  description = "The Azure region the workbooks live in."
  type        = string
  nullable    = false
}

variable "resource_group_id" {
  description = "The id of the resource group the workbooks land in (workbooks are Microsoft.Insights resources, resource group scoped). Parsed for the resource group name."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+$", var.resource_group_id))
    error_message = "resource_group_id must be a resource group id (/subscriptions/<sub>/resourceGroups/<name>)."
  }
}

variable "tags" {
  description = "Tags applied to every workbook and template (merged with any per-item tags)."
  type        = map(string)
  default     = {}
}

variable "workbook_templates" {
  description = <<DESC
Workbook gallery templates keyed by a label. Templates appear in the workbook gallery's Templates
tab for self-serve instantiation instead of cluttering saved workbooks. template_data is the
template JSON; galleries defaults to the Sentinel workbook gallery
(microsoft.securityinsightsarg/sentinel) under the given category.
DESC

  type = map(object({
    template_data = string

    author    = optional(string)
    priority  = optional(number)
    localized = optional(string)
    tags      = optional(map(string))

    galleries = optional(list(object({
      category      = string
      name          = optional(string)
      order         = optional(number)
      resource_type = optional(string, "microsoft.securityinsightsarg/sentinel")
      type          = optional(string, "workbook")
    })))
  }))
  default = {}

  validation {
    condition     = alltrue([for t in values(var.workbook_templates) : can(jsondecode(t.template_data))])
    error_message = "template_data must be valid JSON."
  }

  validation {
    condition     = alltrue([for t in values(var.workbook_templates) : t.localized == null ? true : can(jsondecode(t.localized))])
    error_message = "localized, when set, must be a valid JSON string of localized template payloads."
  }
}

variable "workbooks" {
  description = <<DESC
Custom workbooks keyed by a label that doubles as the display name unless display_name is set.
data_json is the workbook body (the JSON from the portal's Advanced Editor, "Gallery Template"
format); the module injects the workspace as the fallback resource id unless the body already
carries one. Azure requires the resource name to be a lowercase UUID: the module derives a
deterministic one from the label (uuidv5); set name to adopt an existing workbook. category
defaults to sentinel so the workbook lands in the Sentinel gallery.

storage_container_id (bring-your-own storage for the workbook content) requires an identity with
data-plane rights on the container, and the two must travel together.
DESC

  type = map(object({
    data_json = string

    name                 = optional(string)
    display_name         = optional(string)
    description          = optional(string)
    category             = optional(string, "sentinel")
    storage_container_id = optional(string)
    tags                 = optional(map(string))

    identity = optional(object({
      type         = string
      identity_ids = optional(list(string))
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for w in values(var.workbooks) : can(jsondecode(w.data_json))])
    error_message = "data_json must be valid JSON (the workbook body from the portal's Advanced Editor)."
  }

  validation {
    condition     = alltrue([for w in values(var.workbooks) : w.name == null ? true : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", w.name))])
    error_message = "name, when set, must be a lowercase UUID (Azure requires workbook names to be lowercase GUIDs); leave it unset for a deterministic UUID derived from the label."
  }

  validation {
    condition     = alltrue([for w in values(var.workbooks) : (w.storage_container_id == null) == (w.identity == null)])
    error_message = "storage_container_id and identity travel together: bring-your-own-storage workbooks need an identity with rights on the container, and an identity has no purpose without the storage."
  }

  validation {
    condition     = alltrue([for w in values(var.workbooks) : w.identity == null ? true : contains(["SystemAssigned", "UserAssigned"], w.identity.type)])
    error_message = "identity.type must be SystemAssigned or UserAssigned."
  }
}

variable "workspace_id" {
  description = <<DESC
The Sentinel workspace the workbooks belong to. Accepts either the Log Analytics workspace id or
the sentinel module's onboarding_id (an onboardingStates id): the workspace id is parsed back out
of it. It becomes each workbook's source (lowercased, as the API demands) so they appear in the
workspace's Sentinel workbook gallery, and it is injected as the fallback resource id so catalog
queries run against the right workspace.
DESC

  type     = string
  nullable = false

  validation {
    condition     = can(regex("(?i)/providers/Microsoft.OperationalInsights/workspaces/[^/]+$", var.workspace_id)) || can(regex("(?i)/providers/Microsoft.OperationalInsights/workspaces/[^/]+/providers/Microsoft.SecurityInsights/onboardingStates/", var.workspace_id))
    error_message = "workspace_id must be a Log Analytics workspace id or a Sentinel onboarding (onboardingStates) id."
  }
}
