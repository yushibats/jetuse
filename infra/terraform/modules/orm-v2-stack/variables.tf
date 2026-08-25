variable "tenancy_ocid" {
  type = string
}

variable "compartment_ocid" {
  type = string
}

variable "deployment_region_label" {
  description = "Resource Manager入力画面で選択したリージョン表示名"
  type        = string
}

variable "deploy_region" {
  description = "OCIリージョン名"
  type        = string
}

variable "deploy_region_key" {
  description = "OCIRのリージョンキー"
  type        = string
}

variable "home_region" {
  description = "Identity DomainとIAMを操作するテナンシのホームリージョン"
  type        = string
}

variable "region_subscriptions_readable" {
  type = bool
}

variable "deploy_region_subscribed" {
  type = bool
}

variable "admin_email" {
  type = string
}

variable "identity_domain_mode" {
  description = "新規Identity Domainまたは既存Domain利用"
  type        = string

  validation {
    condition     = contains(["新しく作成（推奨）", "既存のIdentity Domainを使用"], var.identity_domain_mode)
    error_message = "Identity Domainの準備方法が正しくありません。"
  }
}

variable "existing_identity_domain_ocid" {
  type    = string
  default = ""
}

variable "create_dynamic_groups" {
  description = "テナンシレベルのJetUse Dynamic Groupを新規作成する"
  type        = bool
}

variable "existing_dynamic_group_name" {
  description = "コンパートメント管理者版で利用する管理者作成済みDynamic Group名"
  type        = string
  default     = ""
}

variable "image_tag" {
  type = string
}

variable "spa_dist_dir" {
  description = "ZIPへ同梱するSPAビルド成果物の絶対またはモジュール相対パス"
  type        = string
}
