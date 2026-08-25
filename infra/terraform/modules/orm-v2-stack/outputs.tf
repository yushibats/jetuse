output "app_url" {
  description = "アプリのURL。ブラウザで開く"
  value       = "https://${module.api_gateway.endpoint}/"
}

output "demo_username" {
  description = "初期管理ユーザー"
  value       = module.identity_domain_app[0].demo_username
}

output "demo_password" {
  description = "デモログインユーザーの初期パスワード"
  # ログインに必要なため RM 出力で表示する。random_password は機微値なので
  # nonsensitive() で明示的にマスクを解除する(プロト用途。本番運用ではVault等を検討)。
  value     = nonsensitive(random_password.demo.result)
  sensitive = false
}

output "oidc_client_id" {
  value = local.oidc_client_id
}

output "identity_domain_url" {
  value = local.domain_url
}

output "runtime_dynamic_group" {
  value = var.create_dynamic_groups ? module.iam.runtime_dynamic_group : var.existing_dynamic_group_name
}

output "adb_dynamic_group" {
  value = var.create_dynamic_groups ? module.iam.adb_dynamic_group : var.existing_dynamic_group_name
}

output "semantic_store_dynamic_group" {
  value = var.create_dynamic_groups ? module.iam.semantic_store_dynamic_group : var.existing_dynamic_group_name
}

output "runtime_policy_id" {
  value = module.iam.runtime_policy_id
}

output "adb_id" {
  value = module.adb.adb_id
}

output "project_ocid" {
  description = "Terraformが作成したGenerative AI Project"
  value       = oci_generative_ai_project.this.id
}

output "preflight_result" {
  description = "Plan時の日本語事前確認結果"
  value       = jsonencode(terraform_data.preflight.output)
}

output "expected_dynamic_group_matching_rule" {
  description = "コンパートメント管理者版で管理者が事前作成するDynamic GroupのMatching Rule"
  value       = local.expected_dynamic_group_matching_rule
}

output "note" {
  value = "初回はIAM反映、ADB作成、DB初期化に時間がかかります。app_urlを開き、demo_username/demo_passwordでログインしてください。SQL Searchはv2 Phase 2で有効化予定です。"
}
