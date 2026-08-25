locals {
  # random_string resourceはApplyまで値が未確定で、バケットのfor_eachを初回Planで
  # 決定できない。入力済みのcompartment OCIDから安定した6文字を算出し、一回のApplyで作れるようにする。
  prefix             = "jetuse-${substr(sha256("${var.compartment_ocid}:${var.deploy_region}"), 0, 6)}"
  admin_username     = "${local.prefix}-admin"
  adb_admin_password = random_password.adb_admin.result
  db_name            = substr(replace(local.prefix, "-", ""), 0, 14)
  deploy_region      = var.deploy_region
  deploy_region_key  = var.deploy_region_key
  home_region        = var.home_region
  ocir_registry      = "${var.deploy_region_key}.ocir.io/idqcucnenh88"
  api_image_url      = "${local.ocir_registry}/jetuse-api:${var.image_tag}"
  fn_router_image    = "${local.ocir_registry}/jetuse-fn-router:${var.image_tag}"

  domain_url = var.identity_domain_mode == "新しく作成（推奨）" ? (
    module.identity_domain[0].domain_url
    ) : (
    try(data.oci_identity_domain.existing[0].url, "")
  )
  oidc_client_id = module.identity_domain_app[0].client_id

  # v2で選べる大阪／シカゴは、どちらもホスト型エージェントの検証・画像配置済みリージョン。
  hosted_agents_enabled = true
  agent_app_ocids       = local.hosted_agents_enabled ? module.hosted_agent[0].app_ocids : {}
  agent_image_registry  = local.ocir_registry

  # コンパートメント管理者版は、管理者が事前作成した単一Dynamic Groupを利用する。
  # 自動診断を曖昧にしないため、管理者向け手順で提示するMatching Ruleとの完全一致を要求する。
  required_dynamic_group_resource_types = [
    "computecontainerinstance",
    "fnfunc",
    "autonomousdatabase",
    "generativeaisemanticstore",
    "generativeaihostedapplication",
    "generativeaihostedapplicationiam",
    "generativeaihosteddeployment",
  ]
  expected_dynamic_group_matching_rule = join("\n", concat(
    ["Any {all {resource.type='${local.required_dynamic_group_resource_types[0]}', resource.compartment.id='${var.compartment_ocid}'},"],
    [for resource_type in slice(local.required_dynamic_group_resource_types, 1, length(local.required_dynamic_group_resource_types) - 1) :
      "     all {resource.type='${resource_type}', resource.compartment.id='${var.compartment_ocid}'},"
    ],
    ["     all {resource.type='${local.required_dynamic_group_resource_types[length(local.required_dynamic_group_resource_types) - 1]}', resource.compartment.id='${var.compartment_ocid}'}}"],
  ))
  existing_dynamic_group = try(one(data.oci_identity_dynamic_groups.existing[0].dynamic_groups), null)
  normalize_expected_dynamic_group_rule = lower(replace(replace(replace(
    local.expected_dynamic_group_matching_rule,
  " ", ""), "\n", ""), "\t", ""))
  normalize_existing_dynamic_group_rule = lower(replace(replace(replace(
    try(local.existing_dynamic_group.matching_rule, ""),
  " ", ""), "\n", ""), "\t", ""))
  existing_dynamic_group_contract_valid = (
    var.create_dynamic_groups
    || local.normalize_existing_dynamic_group_rule == local.normalize_expected_dynamic_group_rule
  )

  # API コンテナとエージェントコンテナの両方が読む素材。
  # api_environment 経由でエージェントへ渡すと
  # api_environment -> module.hosted_agent -> api_environment の循環参照になるため、
  # 共有分だけをここに切り出して両者が参照する。
  shared_runtime_environment = {
    OCI_REGION         = local.deploy_region
    COMPARTMENT_OCID   = var.compartment_ocid
    PROJECT_OCID       = oci_generative_ai_project.this.id
    AUTH_MODE          = "resource_principal"
    ADB_QUERY_PASSWORD = random_password.jetuse_query.result
    ADB_DSN            = "${local.db_name}_low"
    # SQL SearchのネイティブTerraform化は実装計画のPhase 2。循環依存を作らず段階移行する。
    SEMSTORE_OCID       = ""
    ADB_WALLET_PASSWORD = random_password.wallet.result
    # ウォレットは Terraform が base64テキストでバケットへ配置(コンテナはobject readで取得・デコード)
    ADB_WALLET_BUCKET = module.object_storage.app_data_bucket
    ADB_WALLET_OBJECT = "adb_wallet.zip.b64"
    ADB_WALLET_BASE64 = "true"
  }

  # Container Instance / Functions に渡す環境変数(jetuse_core.settings のフィールド名に対応)。
  # CIは OIDC issuer/JWKS のみ参照し client_id には依存しない(循環回避)。
  api_environment = merge(local.shared_runtime_environment, {
    PROJECT_AUTOCREATE = "false"
    AUTH_REQUIRED      = "true"
    OIDC_ISSUER        = "https://identity.oraclecloud.com/"
    OIDC_JWKS_URL      = "${local.domain_url}/admin/v1/SigningCert/jwk"
    # Select AI は ADB のリソースプリンシパル資格情報を使う(bootstrapがENABLE_RESOURCE_PRINCIPAL)
    SELECT_AI_CREDENTIAL = "OCI$RESOURCE_PRINCIPAL"
    # DB自己ブートストラップ(entrypoint.sh → jetuse_core.bootstrap)
    RUN_DB_BOOTSTRAP   = "true"
    ADB_ADMIN_PASSWORD = local.adb_admin_password
    ADB_USER           = "JETUSE_APP"
    ADB_QUERY_USER     = "JETUSE_QUERY"
    ADB_PASSWORD       = random_password.jetuse_app.result
    ADB_OCID           = module.adb.adb_id # フォールバック(バケット未配置時にAPI生成)
    RAG_BUCKET         = module.object_storage.app_data_bucket
    SPEECH_BUCKET      = module.object_storage.speech_bucket
    OS_NAMESPACE       = module.object_storage.namespace
    # Monitoring 名前空間は prefix 由来にする(既定 "jetuse_dev" のままだと別テナンシに
    # dev 名前空間が出る)。名前空間はハイフン不可なので "_" へ正規化。
    METRICS_NAMESPACE = replace(local.prefix, "-", "_")
    # 管理ダッシュボード(/admin)の閲覧者。空のままだと is_admin が常に false になり、
    # ワンクリック配備では誰も /api/admin/usage を開けない(403)。認証有効時は
    # スタックが作る唯一のログインユーザーを既定の管理者にする。
    # JWTのsubjectと一致する、スタック固有の初期管理ユーザー名を渡す。
    ADMIN_USERS = local.admin_username
  })

  # ホスト型エージェントのコンテナへ渡す環境変数。API コンテナ用の設定(OIDC / bootstrap /
  # 管理者 / 書き込み系バケット)は不要なので共有分だけを渡す(最小権限・最小設定)。
  agent_environment = local.shared_runtime_environment

  # エージェント invoke 用の OAuth 資格情報と Application OCID。
  # **API の Container Instance にだけ**渡す。Functions ルーターが担当するのは
  # presets / dbchat / tts でエージェントを呼ばないため、同じ map に載せると
  # client_secret を必要のない実行体へ配ることになる(review F-006)。
  # 未配備なら空のままで、アプリは理由付きで縮退する(jetuse_core.hosted_agent.availability)。
  hosted_agent_environment = {
    HOSTED_AGENT_IDCS_DOMAIN   = local.hosted_agents_enabled ? local.domain_url : ""
    HOSTED_AGENT_CLIENT_ID     = local.hosted_agents_enabled ? module.hosted_agent[0].client_id : ""
    HOSTED_AGENT_CLIENT_SECRET = local.hosted_agents_enabled ? module.hosted_agent[0].client_secret : ""
    HOSTED_AGENT_SCOPE         = local.hosted_agents_enabled ? module.hosted_agent[0].scope : ""
    # 「配備する構成か」をアプリへ伝える。未配備を故障扱いして /api/health 全体を
    # 赤くしないための区別に使う(review F-007)。
    HOSTED_AGENTS_ENABLED    = local.hosted_agents_enabled ? "true" : "false"
    AGENT_OPENAI_APP_OCID    = lookup(local.agent_app_ocids, "openai", "")
    AGENT_LANGGRAPH_APP_OCID = lookup(local.agent_app_ocids, "langgraph", "")
    AGENT_ADK_APP_OCID       = lookup(local.agent_app_ocids, "adk", "")
  }
}
