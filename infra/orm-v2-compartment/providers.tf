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

provider "oci" {
  region = local.deploy_region
}

# 購読確認はResource Managerジョブが実行される購読済みリージョンから行う。
provider "oci" {
  alias  = "bootstrap"
  region = var.region
}

data "oci_identity_region_subscriptions" "this" {
  provider   = oci.bootstrap
  tenancy_id = var.tenancy_ocid
}

# Identity Domain、Dynamic Groupの参照、コンパートメントPolicyはホームリージョンで操作する。
provider "oci" {
  alias  = "home"
  region = local.home_region
}
