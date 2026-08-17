# JetUse ORM v2（初心者向け・構築中）

`infra/orm-v2` は、初めてOCIのAIサービスを使う利用者向けに、既存の
`infra/orm` とは分離して作っている次期Resource Managerテンプレートです。
現行版を上書きせず、完成条件を満たしてから `jetuse-orm-v2.zip` として公開します。

標準版はDynamic GroupとPolicyを含めて新規作成するため、実行ユーザーにはテナンシIAMを
管理できる権限が必要です。Identity Domainで「既存を使用」を選んでも、このIAM要件は変わりません。

> 現在はPhase 1です。入力画面、固定構成、リージョン購読確認、Identity Domainの分岐、
> Generative AI ProjectのTerraform管理、基本事前確認までは実装済みです。
> SQL Search（Vault / Database Tools / Semantic Store / enrichment）はPhase 2のため、
> このブランチのZIPはまだ一般公開・本番利用しません。

## 入力画面

通常は次の4項目だけを入力します。

| 表示名 | 内容 |
|---|---|
| デプロイするリージョン | 大阪（推奨）またはシカゴ |
| コンパートメント | JetUse専用リソースを作成するコンパートメント |
| 初期管理者のメールアドレス | 作成するJetUse初期管理ユーザーのメールアドレス |
| Identity Domainの準備方法 | `新しく作成`（推奨）または`既存を使用` |

`既存を使用`を選んだときだけ、5項目目の「使用するIdentity Domain」が表示されます。
リソース名は `jetuse-<自動生成6文字>` として自動生成します。6文字はコンパートメントと
選択リージョンから安定して算出するため、初回Planで確定し、再Applyでも変わりません。
同じコンパートメント・同じリージョンには、標準版スタックを1つだけ作成してください。

### 新しく作成（推奨）

JetUse専用のIdentity Domain、OIDCログインアプリ、初期管理ユーザーを作成します。
Identity DomainとテナンシIAMを作成できる管理者権限が必要です。

### 既存のIdentity Domainを使用

選択したACTIVEなDomain内に、JetUse専用OIDCログインアプリと初期管理ユーザーを
作成します。既存Domain自体はTerraformの管理対象にせず、変更・削除しません。
JWT検証に必要な「署名証明書へのパブリック・アクセス」がすでに有効かをPlanで確認し、
無効ならDomain管理者へ依頼する日本語エラーで停止します。

## 固定する構成

- 大阪（`ap-osaka-1`）またはシカゴ（`us-chicago-1`）
- 新規VCN、パブリック／プライベートサブネット、セキュリティ設定
- Autonomous Database 26ai、2 ECPU、DBパスワードとWalletの自動生成
- 新規Dynamic GroupとRuntime Policy
- 新規Generative AI Project
- Container Instance、Functions、API Gateway、Object Storage、SPA
- Hosted Agent 3種類（アイドル時レプリカ0）
- OIDC認証あり、OpenSearchなし、APIレート上限20 req/s
- 動作確認済みOCI Provider `8.26.0`

## Plan時の事前確認

Terraformが確実に判定できる項目は、自己申告チェックボックスではなくPlanで停止します。

| 結果 | 判定 |
|---|---|
| 新規作成可能 | 選択した大阪／シカゴを購読済み |
| 実行ユーザーの権限が不足 | リージョン購読を参照できない |
| リージョンが未購読 | 選択リージョンがテナンシの購読一覧にない |
| Identity Domainを利用できない | 既存DomainがACTIVEでない、または参照できない |
| Identity Domainの事前設定が必要 | 既存Domainの署名証明書パブリック・アクセスが無効 |

「リージョンが未購読」と表示された場合は、OCIコンソールの「リージョン管理」から
表示されたリージョン（`ap-osaka-1` または `us-chicago-1`）をサブスクライブします。
購読が完了してからResource ManagerのPlanを再実行してください。

サービス上限と任意の手作業Policyの「意味的な充足」は、Terraform Planだけでは
完全判定できません。標準版はIAMを必ず新規作成し、既存IAMの自動再利用を行わないことで
曖昧さをなくします。ADB ECPUなどの上限は、Phase 3でOCI Limits APIを使った検証の
対応可否を実機確認し、誤判定しないものだけ追加します。

このため標準版では「既存IAMを使う」という入力自体を表示しません。手作業で準備した
Dynamic Group／Policyを利用する組織向け版は別テンプレートにし、必要なresource type、
対象コンパートメント、Policy文が揃っているかをPlan前に検査する計画です。

## テンプレートを分ける条件

初心者向け画面にチェックボックスを増やさず、次は別テンプレートとして扱います。

| 利用形態 | 扱い |
|---|---|
| 管理者が全リソースを新規作成 | ORM v2標準版 |
| IAMを管理者が事前準備 | 組織向けテンプレート |
| 既存VCN・ADB・Semantic Storeを再利用 | 上級者向けテンプレート |
| 認証なし | 開発者向けテンプレート |
| OpenSearchを追加 | 高コストの追加テンプレート |
| 大阪／シカゴ以外 | 標準版では選択不可。リージョン検証後に別配布 |

詳細な段階、依存関係、完成条件は
[ORM v2実装計画](../plan-orm-v2.md)を参照してください。
