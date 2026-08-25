# リージョン診断はルートに置き、Resource Manager入力に対する失敗を直接テストできるようにする。
resource "terraform_data" "region_preflight" {
  input = var.deployment_region

  lifecycle {
    precondition {
      condition     = local.region_subscriptions_readable
      error_message = "【実行ユーザーの権限が不足】テナンシのリージョン購読一覧を取得できません。デプロイ実行ユーザーに inspect tenancies in tenancy を許可してから、Planを再実行してください。"
    }

    precondition {
      condition     = !local.region_subscriptions_readable || local.deploy_region_subscribed
      error_message = "【リージョンが未購読】選択した${var.deployment_region}をこのテナンシで利用できません。OCIコンソールの「リージョン管理」から${local.deploy_region}をサブスクライブし、購読完了後にPlanを再実行してください。"
    }
  }
}

# テナンシIAM管理者向け: Dynamic Group、Policy、アプリ基盤をすべて新規作成する。
module "jetuse" {
  source = "../terraform/modules/orm-v2-stack"
  providers = {
    oci      = oci
    oci.home = oci.home
  }

  tenancy_ocid                  = var.tenancy_ocid
  compartment_ocid              = var.compartment_ocid
  deployment_region_label       = var.deployment_region
  deploy_region                 = local.deploy_region
  deploy_region_key             = local.deploy_region_key
  home_region                   = local.home_region
  region_subscriptions_readable = local.region_subscriptions_readable
  deploy_region_subscribed      = local.deploy_region_subscribed
  admin_email                   = var.admin_email
  identity_domain_mode          = var.identity_domain_mode
  existing_identity_domain_ocid = var.existing_identity_domain_ocid
  create_dynamic_groups         = true
  existing_dynamic_group_name   = ""
  image_tag                     = var.image_tag
  spa_dist_dir                  = "${path.module}/../../packages/web/dist"

  depends_on = [terraform_data.region_preflight]
}
