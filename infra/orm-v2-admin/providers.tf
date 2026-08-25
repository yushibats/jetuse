terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "= 8.26.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.9.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "= 0.14.0"
    }
  }
}

# Resource Managerがプリンシパル認証を注入する。アプリのリソースは画面で選んだ
# 大阪／シカゴへ作成する。
provider "oci" {
  region = local.deploy_region
}

# リージョン購読一覧は、Resource Managerジョブ自身が動いている購読済みリージョンから読む。
# 未購読のデプロイ先を既定providerへ設定しても、事前確認だけは確実に実行できるように分離する。
provider "oci" {
  alias  = "bootstrap"
  region = var.region
}

# Identity系のCREATEはホームリージョン必須。ユーザー入力は誤入力で失敗するため
# region subscriptionsから自動導出する(deployer policyの inspect tenancies で参照可)。
data "oci_identity_region_subscriptions" "this" {
  provider   = oci.bootstrap
  tenancy_id = var.tenancy_ocid
}

# 権限不足だと region_subscriptions は **null** になり(401/404 ではない)、生の for 式は
# "Iteration over null value" で落ちる。原因が権限だと分からないメッセージになるので、
# ここはlocals.home_region(try付き)を使い、判定と案内はmain.tfのpreflightに集約する。
provider "oci" {
  alias  = "home"
  region = local.home_region
}
