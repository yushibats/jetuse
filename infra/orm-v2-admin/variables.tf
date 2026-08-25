# OCI Resource Managerが自動注入するため入力画面には表示しない。
variable "tenancy_ocid" {
  type = string
}

variable "region" {
  type = string
}

# 管理者向け入力は以下の4項目 + 既存Domain選択時だけ表示する1項目に限定する。
variable "compartment_ocid" {
  description = "JetUseの全リソースを新規作成するコンパートメント"
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

variable "identity_domain_mode" {
  description = "Identity Domainを新規作成するか、既存Domainを利用するか"
  type        = string
  default     = "新しく作成（推奨）"

  validation {
    condition     = contains(["新しく作成（推奨）", "既存のIdentity Domainを使用"], var.identity_domain_mode)
    error_message = "Identity Domainの準備方法は「新しく作成」または「既存を使用」を選択してください。"
  }
}

variable "existing_identity_domain_ocid" {
  description = "既存Identity DomainのOCID（既存利用の場合のみ）"
  type        = string
  default     = ""

  validation {
    condition = (
      trimspace(var.existing_identity_domain_ocid) == ""
      || can(regex("^ocid1\\.domain\\.", var.existing_identity_domain_ocid))
    )
    error_message = "Identity Domain OCIDの形式が正しくありません。"
  }
}

# 公開ZIP生成時にcommit SHAへ固定する内部値。schema.yamlでは常に非表示。
variable "image_tag" {
  description = "JetUseコンテナ群に共通する内部リリースタグ"
  type        = string
  default     = "latest"
}
