variable "prefix" {
  type = string
}

variable "idcs_endpoint" {
  description = "Identity DomainのIDCSエンドポイント(https://idcs-xxxx.identity.oraclecloud.com)"
  type        = string
}

variable "redirect_uri" {
  description = "OIDCリダイレクトURI(= https://<API GWホスト>/)"
  type        = string
}

variable "demo_email" {
  description = "デモログインユーザーのメール"
  type        = string
  default     = "demo@example.com"
}

variable "demo_username" {
  description = "作成するログインユーザー名。既定値は現行ORMとの互換用"
  type        = string
  default     = "demo"
}

variable "demo_password" {
  description = "デモユーザーの初期パスワード(自動生成)"
  type        = string
  sensitive   = true
}

# Identity Domain はホームリージョンにあるため、oci CLI の呼び出しにも同リージョンを渡す。
variable "home_region" {
  description = "テナンシのホームリージョン(Identity Domain の所在。空ならCLI既定に委ねる)"
  type        = string
  default     = ""
}

variable "manage_domain_settings" {
  description = "Manage the domain-wide signing certificate setting. Disable when attaching JetUse to a pre-existing domain."
  type        = bool
  default     = true
}
