# OCI Resource Managerが自動注入するため入力画面には表示しない。
variable "tenancy_ocid" {
  type = string
}

variable "region" {
  type = string
}

variable "compartment_ocid" {
  description = "JetUseの全リソースを新規作成する専用コンパートメント"
  type        = string
}

variable "deployment_region" {
  description = "JetUseを構築するリージョン"
  type        = string
  default     = "大阪（ap-osaka-1・推奨）"

  validation {
    condition = contains([
      "大阪（ap-osaka-1・推奨）",
      "シカゴ（us-chicago-1）",
    ], var.deployment_region)
    error_message = "デプロイ先は大阪またはシカゴを選択してください。"
  }
}

variable "admin_email" {
  description = "JetUse初期管理ユーザーのメールアドレス"
  type        = string

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.admin_email))
    error_message = "初期管理者のメールアドレスを正しい形式で入力してください。"
  }
}

variable "existing_dynamic_group_name" {
  description = "テナンシ管理者がJetUse用に事前作成したDynamic Group名"
  type        = string

  validation {
    condition = (
      trimspace(var.existing_dynamic_group_name) != ""
      && !strcontains(var.existing_dynamic_group_name, "\n")
    )
    error_message = "管理者から案内されたDynamic Group名を入力してください。"
  }
}

variable "image_tag" {
  description = "JetUseコンテナ群に共通する内部リリースタグ"
  type        = string
  default     = "latest"
}
