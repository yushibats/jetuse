# JetUse ORM v2 — 権限別かんたんデプロイ

ORM v2は、利用者の権限に合わせて2つのResource Managerテンプレートに分かれています。
リポジトリは分けず、共通のTerraformモジュールから別々のZIPを生成します。

> SQL Search（Vault / Database Tools / Semantic Store / enrichment）の完全自動化はPhase 2です。
> 現在のZIPは入力画面、IAM分離、リージョン購読確認、Identity Domain/OAuth、基本アプリ基盤までを対象とします。

## どちらを使うか

| 実行者 | テンプレート | ZIP | 管理者の事前作業 |
|---|---|---|---|
| Dynamic GroupとPolicyを作成できるテナンシIAM管理者 | 管理者版 | `jetuse-orm-admin.zip` | なし |
| JetUse専用コンパートメントの`manage all-resources`だけを持つユーザー | コンパートメント版 | `jetuse-orm-compartment.zip` | Dynamic Group 1本とデプロイ権限Policy |

### 管理者版

[![Deploy JetUse as a tenancy IAM administrator](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/sogawa-yk/jetuse/releases/download/orm-main/jetuse-orm-admin.zip)

通常の入力は次の4項目です。

| 入力 | 内容 |
|---|---|
| デプロイするリージョン | 大阪（推奨）またはシカゴ |
| コンパートメント | JetUse専用リソースの作成先 |
| 初期管理者のメールアドレス | JetUse初期管理ユーザー |
| Identity Domainの準備方法 | 新規作成または既存Domain利用 |

既存Domain利用時だけDomain選択が追加表示されます。それ以外のVCN、ADB、Dynamic Group、
Policy、Generative AI Project、アプリリソースはすべて新規作成します。

### コンパートメント管理者版

[![Deploy JetUse as a compartment administrator](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/sogawa-yk/jetuse/releases/download/orm-main/jetuse-orm-compartment.zip)

入力は次の4項目です。

| 入力 | 内容 |
|---|---|
| デプロイするリージョン | 大阪（推奨）またはシカゴ |
| JetUse専用コンパートメント | `manage all-resources`を付与された作成先 |
| 初期管理者のメールアドレス | JetUse初期管理ユーザー |
| 管理者が準備したDynamic Group名 | 下記Matching Ruleを持つACTIVEなDynamic Group |

既存・共有Identity Domainは選択しません。JetUse専用の無料Identity Domainを対象コンパートメントに
新規作成し、その中にOAuthアプリと初期管理ユーザーをTerraformで作成します。

## Identity DomainとOAuthアプリの扱い

どちらのテンプレートも次の2種類を自動作成します。

- SPAログイン用: `public`クライアント、Authorization Code + PKCE
- Hosted Agent用: `confidential`クライアント兼OAuth resource、Client Credentials、Audience/Scope、Client Secret

専用コンパートメントの`manage all-resources`だけを持つユーザーでも、同じコンパートメント内の
Identity Domain作成と、Domain内のApp/User/Grant/Setting管理を実機確認済みです。そのため
コンパートメント版でClient IDやClient Secretを手入力する必要はありません。

管理者版で別コンパートメントの既存・共有Domainを利用する場合は、そのDomainを管理できる権限が必要です。
既存Domainの署名証明書パブリック・アクセスが無効なら、TerraformはDomainを変更せずPlanで停止します。

## コンパートメント版を使う前の管理者作業

### 1. Dynamic Groupを1本作成

`<compartment_ocid>`をJetUse専用コンパートメントのOCIDへ置き換えます。名前は任意ですが、
デプロイ担当者へ正確な名前を渡してください。

```text
Any {all {resource.type='computecontainerinstance', resource.compartment.id='<compartment_ocid>'},
     all {resource.type='fnfunc', resource.compartment.id='<compartment_ocid>'},
     all {resource.type='autonomousdatabase', resource.compartment.id='<compartment_ocid>'},
     all {resource.type='generativeaisemanticstore', resource.compartment.id='<compartment_ocid>'},
     all {resource.type='generativeaihostedapplication', resource.compartment.id='<compartment_ocid>'},
     all {resource.type='generativeaihostedapplicationiam', resource.compartment.id='<compartment_ocid>'},
     all {resource.type='generativeaihosteddeployment', resource.compartment.id='<compartment_ocid>'}}
```

Terraformは空白と改行を除いてこのRuleと完全一致するか確認します。対象コンパートメント、
Resource Type、条件が不足・過剰な場合は、日本語エラーと期待するRuleを表示して停止します。

### 2. デプロイ担当グループへ権限を付与

`<domain>/<group>`と`<compartment_ocid>`を置き換えます。

```text
Allow group <domain>/<group> to inspect tenancies in tenancy
Allow group <domain>/<group> to inspect compartments in tenancy
Allow group <domain>/<group> to inspect dynamic-groups in tenancy
Allow group <domain>/<group> to manage all-resources in compartment id <compartment_ocid>
```

- `inspect tenancies`: リージョン購読一覧とホームリージョンの取得
- `inspect compartments`: Deploy画面でのコンパートメント選択
- `inspect dynamic-groups`: 事前作成済みDynamic Groupの存在とMatching Ruleの検査
- `manage all-resources in compartment`: Runtime Policy、Identity Domain/OAuth、JetUse本体の作成

Dynamic Groupはテナンシに属するためコンパートメント管理者版では作成しません。一方、Runtime Policyは
JetUse専用コンパートメント内にTerraformが作成するため、管理者による事前作成は不要です。

## Plan時の事前確認

| 診断 | 次の操作 |
|---|---|
| リージョン購読一覧を取得できない | `inspect tenancies in tenancy`を管理者へ依頼 |
| 大阪/シカゴが未購読 | OCIコンソールの「リージョン管理」で対象リージョンをサブスクライブ |
| Dynamic Groupが見つからない | 名前、ACTIVE状態、`inspect dynamic-groups`を確認 |
| Matching Ruleが一致しない | エラーに表示されたRuleへ管理者が更新 |
| 既存Identity Domainが利用できない（管理者版のみ） | Domain状態、管理権限、署名証明書設定を確認 |

OCIのPolicy文が実行者へどのように継承されているかや、サービス上限を変更せず完全判定することは
できません。読み取りAPIで確実に判定できる項目だけをPlanで診断します。

## 固定構成

- 大阪（`ap-osaka-1`）またはシカゴ（`us-chicago-1`）
- 新規VCN、パブリック/プライベートサブネット、NSG
- Autonomous Database 26ai、2 ECPU、Walletとパスワードの自動生成
- 新規Runtime PolicyとGenerative AI Project
- Container Instance、Functions、API Gateway、Object Storage、SPA
- Hosted Agent 3種類、アイドル時レプリカ0
- OIDC認証あり、OpenSearchなし、APIレート上限20 req/s
- OCI Provider `8.26.0`、Terraform `>= 1.5.0`

実装段階と完成条件は[ORM v2実装計画](../plan-orm-v2.md)を参照してください。
