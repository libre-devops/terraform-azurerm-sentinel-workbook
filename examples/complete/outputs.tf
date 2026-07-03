output "workbook_ids_zipmap" {
  description = "Map of workbook label to { name, id } (feed metadata parent_id from this)."
  value       = module.sentinel_workbook.workbook_ids_zipmap
}

output "workbook_template_ids" {
  description = "Map of template label to id."
  value       = module.sentinel_workbook.workbook_template_ids
}
