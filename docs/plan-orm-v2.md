# JetUse ORM v2 実装計画

## 目的

利用者がコンパートメント、管理者メール、Identity Domainの準備方法だけを選び、
日本語のPlan診断を確認してApplyすると、SQL Searchを含むJetUseを利用できる状態を
完成条件とする。現行 `infra/orm` の互換性は維持し、v2は独立したZIPで配布する。

## 設計原則

1. 標準版はIdentity Domain以外の既存リソースを再利用しない。
2. 実装詳細や高度な選択肢は入力画面に出さず、動作確認済み値へ固定する。
3. 管理権限やコストモデルが異なる構成は条件分岐ではなく別テンプレートにする。
4. 自動確認できない内容を「確認済み」チェックボックスで利用者へ転嫁しない。
5. Planで止める診断は、OCI APIから再現可能に判定できるものだけにする。
6. Terraform 1.5.7で動作し、条件付きimportなど新しいTerraform機能に依存しない。

## 実装段階

### Phase 1 — 入力削減と固定構成（実装済み）

- `infra/orm-v2` を現行版から分離
- 入力を通常3項目、既存Domain利用時4項目へ削減
- 「新しく作成（推奨）」／「既存のIdentity Domainを使用」の単一選択
- `jetuse-<ランダム6文字>` の名前生成
- 大阪固定、IAM新規作成、認証あり、OpenSearchなし、固定サイズ
- リージョン購読・大阪・既存Domain ACTIVEの日本語preflight
- Generative AI Projectを `oci_generative_ai_project` で管理
- OCI Providerを `8.26.0` に固定

### Phase 2 — SQL SearchのTerraform管理（未実装）

構築順序を次に固定する。

1. ADBとWalletを作成
2. 再実行可能なDB初期化工程で `JETUSE_APP` / `JETUSE_QUERY` とスキーマを作成
3. Vault、KMS Key、ADMIN／JETUSE_QUERYのSecretを作成
4. enrichment用ADMIN接続とquery用JETUSE_QUERY接続を作成・検証
5. `oci_generative_ai_semantic_store` を作成
6. SHスキーマのFULL_BUILD enrichmentを開始し、成功まで待機
7. Semantic Store OCIDを渡してAPIコンテナを起動

現行はAPIコンテナ起動後にDBユーザーを作るため、そのままSemantic Storeを参照すると
`APIコンテナ → Semantic Store → query接続 → JETUSE_QUERY → APIコンテナ` の循環が生じる。
Phase 2の最初にDB初期化を一回限りの独立工程へ切り出し、失敗状態と完了状態を
Terraformが判定できる方式を実機スパイクする。次の合格条件を満たさない方式は採用しない。

- Resource Manager上で追加のローカルツールを利用者に要求しない
- 初回Apply一回で完了する
- 再Applyが冪等で、パスワードをログへ出さない
- DB初期化失敗時にSemantic Storeとアプリを作り始めない
- DestroyでTerraform管理リソースを追跡できる

### Phase 3 — 事前診断の拡張（未実装）

- ADB ECPUなど、リージョンごとに安定して取得できるサービス上限
- 公開コンテナイメージの対象タグ存在確認
- 同じv2スタック由来の中途半端な残存リソースの検出
- 診断結果を「新規作成可能／権限不足／サービス上限不足」に分類

手作業Policyの意味判定は文の順序、変数、より広い権限を含むため完全ではない。
組織向けテンプレートでは、JetUseが定義する正規化済みIAM契約と完全一致する
Dynamic Group／Policyだけを自動再利用の対象にする。

組織向けテンプレートのpreflightは、作成処理より先に次を読み取る。

- 必要なDynamic Groupが存在するか
- Matching RuleにContainer Instance、Functions、ADB、Semantic Store、Hosted Agentの
  必要なresource typeと対象コンパートメントが含まれるか
- JetUseが定義するRuntime Policy文がすべて存在するか
- Dynamic Groupだけ、またはPolicyだけが残った部分構成ではないか
- 実行ユーザーがDynamic GroupとPolicyを参照できるか

結果は「必要なIAMがすべて準備済み」「IAMが一部だけ存在するため修正が必要」
「実行ユーザーの権限が不足」に分類する。より広いPolicyや独自の変数・条件を含むPolicyは
自動で十分とみなさず、上級者向けの手順へ案内する。

### Phase 4 — パッケージと実機ゲート（進行中）

- CIで `infra/orm-v2` と `jetuse-orm-v2.zip` をTerraform 1.5.7でvalidate
- 一般公開Releaseにはまだ添付しない
- 新規テナンシ、管理者権限不足、IAM部分残存、上限不足、再Apply、Destroyを実機確認
- 全項目合格後にv2のDeploy to Oracle Cloudボタンを追加

## 完成判定

- Resource Manager入力画面が意図した3〜4項目だけである
- Planのエラーが日本語で原因と次の操作を示す
- 新規Domain／既存Domainの両方でログインできる
- Generative AI ProjectとSemantic StoreのOCIDがアプリへ直接渡る
- SQL Searchのenrichmentが成功し、JetUseから問合せできる
- 再Applyに差分がなく、Destroy後に管理対象が残らない
- 既存 `jetuse-orm.zip` の内容・挙動が変わらない
