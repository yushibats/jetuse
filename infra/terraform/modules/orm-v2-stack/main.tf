# JetUse ORM v2の共有実装。管理者版／コンパートメント管理者版のルートから呼び出す。

data "oci_identity_dynamic_groups" "existing" {
  count          = var.create_dynamic_groups ? 0 : 1
  provider       = oci.home
  compartment_id = var.tenancy_ocid
  name           = var.existing_dynamic_group_name
  state          = "ACTIVE"
}

data "oci_identity_domain" "existing" {
  count = (
    var.identity_domain_mode == "既存のIdentity Domainを使用"
    && trimspace(var.existing_identity_domain_ocid) != ""
  ) ? 1 : 0
  provider  = oci.home
  domain_id = var.existing_identity_domain_ocid
}

# 既存Domainは変更しない。JWT検証に必要な公開署名証明書がDomain管理者によって
# 設定済みかを読み取り、未設定ならPlanで止める。
data "oci_identity_domains_setting" "existing" {
  count = (
    var.identity_domain_mode == "既存のIdentity Domainを使用"
    && trimspace(var.existing_identity_domain_ocid) != ""
  ) ? 1 : 0

  provider      = oci.home
  idcs_endpoint = try(data.oci_identity_domain.existing[0].url, "")
  setting_id    = "Settings"
}

# Planで確実に確認できる項目だけを日本語で診断する。IAMの文意やサービス上限のように
# APIだけでは完全判定できない項目を「確認済み」チェックボックスで利用者へ転嫁しない。
resource "terraform_data" "preflight" {
  input = {
    deployment_region = var.deploy_region_subscribed ? "新規作成可能: ${var.deployment_region_label}" : "停止: ${var.deployment_region_label}は未購読です"
    iam = var.create_dynamic_groups ? (
      "新規作成: JetUse専用Dynamic GroupとRuntime Policy"
      ) : (
      "確認済み: 既存Dynamic Group ${var.existing_dynamic_group_name} / 新規作成: Runtime Policy"
    )
    identity_domain = var.identity_domain_mode == "新しく作成（推奨）" ? (
      "新規作成: JetUse専用Identity Domain"
      ) : (
      "再利用: ${try(data.oci_identity_domain.existing[0].display_name, var.existing_identity_domain_ocid)}"
    )
  }

  lifecycle {
    precondition {
      condition     = var.create_dynamic_groups || trimspace(var.existing_dynamic_group_name) != ""
      error_message = "【Dynamic Groupが未入力】コンパートメント管理者版では、テナンシ管理者が事前作成したDynamic Group名を入力してください。"
    }

    precondition {
      condition = (
        var.create_dynamic_groups
        || length(try(data.oci_identity_dynamic_groups.existing[0].dynamic_groups, [])) == 1
      )
      error_message = "【Dynamic Groupを確認できません】入力したACTIVEなDynamic Groupが見つかりません。名前と inspect dynamic-groups in tenancy 権限を確認してください。"
    }

    precondition {
      condition     = local.existing_dynamic_group_contract_valid
      error_message = "【Dynamic GroupのMatching Ruleが不足】JetUseが必要とする7種類のResource Principalと対象コンパートメントを完全にはカバーしていません。管理者向け手順に記載したMatching Ruleへ更新してからPlanを再実行してください。期待するRule: ${local.expected_dynamic_group_matching_rule}"
    }

    precondition {
      condition = (
        var.identity_domain_mode != "既存のIdentity Domainを使用"
        || trimspace(var.existing_identity_domain_ocid) != ""
      )
      error_message = "【Identity Domainが未選択】既存のIdentity Domainを使用する場合は、使用するDomainを選択してください。"
    }

    precondition {
      condition = (
        var.identity_domain_mode != "既存のIdentity Domainを使用"
        || try(data.oci_identity_domain.existing[0].state, "") == "ACTIVE"
      )
      error_message = "【Identity Domainを利用できません】選択したIdentity DomainがACTIVEではありません。Domainの状態と、実行ユーザーの参照権限を確認してください。"
    }

    precondition {
      condition = (
        var.identity_domain_mode != "既存のIdentity Domainを使用"
        || try(data.oci_identity_domains_setting.existing[0].signing_cert_public_access, false)
      )
      error_message = "【Identity Domainの事前設定が必要】既存Domainの「署名証明書へのパブリック・アクセス」を有効にしてください。v2は既存Domainの設定を変更しません。"
    }
  }
}

# --- 自動生成パスワード(Oracle/IDCS規則: 英大小+数字+記号, " を含めない) ---
resource "random_password" "adb_admin" {
  length           = 20
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 1
  override_special = "#_-"
}
resource "random_password" "wallet" {
  length           = 20
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 1
  override_special = "#_-"
}
resource "random_password" "jetuse_app" {
  length           = 20
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 1
  override_special = "#_-"
}
resource "random_password" "jetuse_query" {
  length           = 20
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 1
  override_special = "#_-"
}
resource "random_password" "demo" {
  length           = 16
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 1
  override_special = "#_-"

  # v2専用のkeeperで現行ORMのパスワード履歴と切り離し、再Applyでは値を維持する。
  keepers = {
    password_setter = "user-password-changer-v1"
    version         = "orm-v2"
  }
}

# IAMもアプリ本体と同じResource Manager stackで新規作成する。
module "iam" {
  source    = "../iam"
  providers = { oci = oci.home }

  tenancy_ocid              = var.tenancy_ocid
  compartment_ocid          = var.compartment_ocid
  prefix                    = local.prefix
  enable_dynamic_group      = var.create_dynamic_groups
  enable_runtime_policy     = true
  enable_semantic_store     = true
  enable_project_autocreate = false
  create_deployer_policy    = false
  # ホスト型エージェントを配備するときだけ runtime DG にホスト型リソースを含める(PORT-03)。
  include_hosted_agent_principals = local.hosted_agents_enabled

  existing_dynamic_group = var.existing_dynamic_group_name

  depends_on = [terraform_data.preflight]
}

module "network" {
  source              = "../network"
  compartment_ocid    = var.compartment_ocid
  prefix              = local.prefix
  public_subnet_cidr  = "10.1.0.0/24"
  private_subnet_cidr = "10.1.1.0/24"

  depends_on = [terraform_data.preflight]
}

module "object_storage" {
  source           = "../object-storage"
  compartment_ocid = var.compartment_ocid
  prefix           = local.prefix
  region           = local.deploy_region

  depends_on = [terraform_data.preflight]
}

module "adb" {
  source           = "../adb"
  compartment_ocid = var.compartment_ocid
  prefix           = local.prefix
  admin_password   = local.adb_admin_password
  db_version       = "26ai"
  ecpu_count       = 2
  # ウォレットをTerraformで生成し、base64テキストでバケットへ配置する(コンテナはobject readのみでOK)
  generate_wallet = true
  wallet_password = random_password.wallet.result

  depends_on = [module.iam]
}

# OCIRリポジトリ(jetuse-api / jetuse-fn-router)はスタックでは作らない(ADR-0011, 2026-06-25)。
# 本番用コンパートメント(genu-proto)に人間が手動で public 作成・管理する。
# 理由: (1) OCIRのrepo名はネームスペース内で一意。stackがjetuse-devに同名repoを作ると衝突する。
#       (2) イメージパスはネームスペースベース(kix.ocir.io/<namespace>/<repo>)でコンパートメント非依存
#           なので、genu-proto に置いても locals.tf のイメージURLはそのまま機能する。
#       (3) push(release.yml)は repo 事前作成済みなら通る(無いとOCIRがルートに作成を試み権限不足で失敗)。

module "observability" {
  source              = "../observability"
  compartment_ocid    = var.compartment_ocid
  prefix              = local.prefix
  apigw_deployment_id = module.api_gateway.deployment_id
  fnapp_id            = module.functions.application_id
}

# RAG / Responses / Conversations が共通で使うProjectは、アプリ起動後の自動作成ではなく
# Terraformの管理対象にする。Destroy時も同じスタックで追跡できる。
resource "oci_generative_ai_project" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.prefix}-project"
  description    = "JetUse ORM v2 managed Generative AI project"

  depends_on = [module.iam]
}

module "functions" {
  source           = "../functions"
  compartment_ocid = var.compartment_ocid
  prefix           = local.prefix
  subnet_id        = module.network.private_subnet_id
  router_image     = local.fn_router_image
  router_config = merge(local.api_environment, {
    AUTH_MODE = "resource_principal"
    LOG_OCID  = module.observability.app_log_id
  })

  # container_instance と同じ理由(destroy 時にバケット掃除より先に止める)
  depends_on = [module.iam, module.object_storage]
}

module "container_instance" {
  source           = "../container-instance"
  compartment_ocid = var.compartment_ocid
  prefix           = local.prefix
  subnet_id        = module.network.private_subnet_id
  nsg_id           = module.network.app_nsg_id
  image_url        = local.api_image_url
  # エージェントの OAuth 資格情報はここだけに渡す(Functions ルーターへは配らない)。
  environment_variables = merge(
    local.api_environment,
    local.hosted_agent_environment,
    { LOG_OCID = module.observability.app_log_id },
  )
  memory_gb = 4
  shape     = "CI.Standard.E4.Flex"

  # destroy の順序担保: モジュール全体に依存させることで、バケットの掃除(object_storage 内の
  # terraform_data.empty_buckets)より先にアプリが停止する。出力参照だけだとバケット resource に
  # しか依存せず、掃除とアプリ停止が並行して走り、掃除後に書き込まれて 409 になりうる。
  depends_on = [module.iam, module.object_storage]
}

locals {
  fn_router_segments = ["presets", "dbchat", "tts"]
  fn_routes = module.functions.router_function_id == "" ? {} : {
    for s in local.fn_router_segments : s => module.functions.router_function_id
  }
}

module "api_gateway" {
  source             = "../api-gateway"
  compartment_ocid   = var.compartment_ocid
  prefix             = local.prefix
  region             = local.deploy_region
  subnet_id          = module.network.public_subnet_id
  nsg_id             = module.network.apigw_nsg_id
  ci_base_url        = "http://${module.container_instance.private_ip}:8000"
  functions_routes   = local.fn_routes
  rate_limit_rps     = 20
  spa_par_access_uri = module.object_storage.spa_par_access_uri
}

module "identity_domain" {
  count            = var.identity_domain_mode == "新しく作成（推奨）" ? 1 : 0
  source           = "../identity-domain"
  providers        = { oci = oci.home }
  compartment_ocid = var.compartment_ocid
  prefix           = local.prefix
  region           = local.deploy_region
  # Identity Domain はテナンシのホームリージョンにしか作れない。deployリージョンではなく
  # ホームリージョンを渡す(deployリージョン≠ホームでの作成失敗を防ぐ)。
  home_region = local.home_region

  depends_on = [terraform_data.preflight]
}

# IAM は作成 API が成功しても、Dynamic Group と policy の反映に実測5〜10分かかる(docs/tips.md)。
# Hosted Deployment は artifact 検証に一度失敗すると FAILED が終端状態になり、apply の再試行で
# しか復旧できない。そこで反映待ちを明示的に挟む(review F-005)。
# この待ちは module.adb(作成に10分以上)と**並行**して進むため、apply 全体の実時間は伸びない。
resource "time_sleep" "iam_propagation" {
  count = local.hosted_agents_enabled ? 1 : 0
  # 実機記録では反映に8分かかった事例がある(docs/tips.md)。既知の上限を覆う値にする。
  create_duration = "600s"

  # IAM の**内容**が変わったら待ち直す。DG 名や policy OCID は matching rule 本文や
  # statement 差し替えでは変わらないので、内容を決める入力の指紋を混ぜる。
  triggers = {
    runtime_dynamic_group = coalesce(module.iam.runtime_dynamic_group, "none")
    runtime_policy_id     = coalesce(module.iam.runtime_policy_id, "none")
    # matching rule 本文と policy statements そのもののハッシュ。変数入力だけを見ていると、
    # モジュール側のコード変更(文の追加など)で待ち直しが起きない。
    iam_content = module.iam.content_fingerprint
  }

  depends_on = [module.iam]
}

# ホスト型エージェント(PORT-03 / ADR-0019)。3SDK の ReAct コンテナを Enterprise AI Agent として
# 配備し、OAuth(client_credentials)の発行元兼リソースを同じスタックで作る。
# 配備条件は locals.hosted_agents_enabled(認証有効 かつ エージェント画像のある kix/ord)。
# min_replica=0 なので、使わない利用者にアイドル課金は発生しない。
module "hosted_agent" {
  count             = local.hosted_agents_enabled ? 1 : 0
  source            = "../hosted-agent"
  compartment_ocid  = var.compartment_ocid
  prefix            = local.prefix
  region            = local.deploy_region
  idcs_endpoint     = local.domain_url
  image_registry    = local.agent_image_registry
  image_repo_prefix = "jetuse"
  image_tag         = var.image_tag
  min_replica       = 0

  environment_variables = local.agent_environment

  # コンテナは resource principal で GenAI / Object Storage(ウォレット) / ADB を呼ぶ。
  # IAM(DG + policy)の**反映完了**とウォレット配置より後に作らないと、初回起動が権限エラーで落ちる。
  depends_on = [time_sleep.iam_propagation, module.object_storage, module.adb]
}

module "identity_domain_app" {
  count         = 1
  source        = "../identity-domain-app"
  prefix        = local.prefix
  idcs_endpoint = local.domain_url
  redirect_uri  = "https://${module.api_gateway.endpoint}/"
  demo_email    = var.admin_email
  demo_username = local.admin_username
  demo_password = random_password.demo.result
  home_region   = local.home_region

  # 既存DomainではDomain全体の設定を変更しない。公開署名証明書はpreflightで確認する。
  manage_domain_settings = var.identity_domain_mode == "新しく作成（推奨）"
}
