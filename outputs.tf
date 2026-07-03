output "example_incident_ids" {
  description = "Map of example incident label to its id (empty unless create_example_incidents is on)."
  value       = { for k, i in azapi_resource.example_incident : k => i.id }
}

output "workbook_ids" {
  description = "Map of workbook label to its id."
  value       = { for k, w in azurerm_application_insights_workbook.this : k => w.id }
}

output "workbook_ids_zipmap" {
  description = "Map of workbook label to { name, id }, for easy composition with other modules (metadata parent_id, for example)."
  value       = { for k, w in azurerm_application_insights_workbook.this : k => { name = w.name, id = w.id } }
}

output "workbook_names" {
  description = "Map of workbook label to the workbook's UUID name (deterministic unless overridden)."
  value       = { for k, w in azurerm_application_insights_workbook.this : k => w.name }
}

output "workbook_template_ids" {
  description = "Map of template label to its id."
  value       = { for k, t in azurerm_application_insights_workbook_template.this : k => t.id }
}

output "workbook_template_ids_zipmap" {
  description = "Map of template label to { name, id }, for easy composition with other modules."
  value       = { for k, t in azurerm_application_insights_workbook_template.this : k => { name = t.name, id = t.id } }
}

output "workbook_templates" {
  description = "Map of template label to the full workbook template object."
  value       = azurerm_application_insights_workbook_template.this
}

output "workbooks" {
  description = "Map of workbook label (catalog and custom) to the full workbook object."
  value       = azurerm_application_insights_workbook.this
}

output "workspace_id" {
  description = "The Log Analytics workspace id the workbooks are pinned to (parsed from an onboarding id when one was given, lowercased)."
  value       = local.workspace_id
}
