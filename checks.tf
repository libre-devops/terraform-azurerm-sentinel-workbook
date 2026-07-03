# check blocks run after every plan and apply and warn (without blocking) on configuration that would
# quietly misbehave.

# A workbook body that carries its own fallbackResourceIds pointing somewhere other than this
# workspace usually means JSON exported from another environment: the workbook will render against
# the wrong workspace.
check "custom_bodies_target_this_workspace" {
  assert {
    condition = alltrue([
      for label, w in var.workbooks : alltrue([
        for rid in try(jsondecode(w.data_json).fallbackResourceIds, []) : lower(rid) == local.workspace_id
      ])
    ])
    error_message = "One or more custom workbook bodies carry fallbackResourceIds for a different workspace; the workbook will query the wrong place."
  }
}
