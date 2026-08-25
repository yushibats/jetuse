output "app_url" {
  value = module.jetuse.app_url
}

output "demo_username" {
  value = module.jetuse.demo_username
}

output "demo_password" {
  value     = module.jetuse.demo_password
  sensitive = false
}

output "oidc_client_id" {
  value = module.jetuse.oidc_client_id
}

output "identity_domain_url" {
  value = module.jetuse.identity_domain_url
}

output "runtime_dynamic_group" {
  value = module.jetuse.runtime_dynamic_group
}

output "adb_dynamic_group" {
  value = module.jetuse.adb_dynamic_group
}

output "semantic_store_dynamic_group" {
  value = module.jetuse.semantic_store_dynamic_group
}

output "runtime_policy_id" {
  value = module.jetuse.runtime_policy_id
}

output "adb_id" {
  value = module.jetuse.adb_id
}

output "project_ocid" {
  value = module.jetuse.project_ocid
}

output "preflight_result" {
  value = module.jetuse.preflight_result
}

output "required_dynamic_group_matching_rule" {
  description = "管理者が事前作成するDynamic GroupのMatching Rule"
  value       = module.jetuse.expected_dynamic_group_matching_rule
}

output "note" {
  value = module.jetuse.note
}
