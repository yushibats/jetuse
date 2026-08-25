# JetUse ORM v2 実装計画

## 目的

初めてOCIのAIサービスを使う利用者が、自分の権限に合うDeployボタンを選び、4項目だけ入力して
JetUseを構築できる状態を完成条件とする。現行`infra/orm`は互換用に維持する。

## 権限境界

複雑な条件分岐を入力画面へ出さず、2つのTerraformルートとZIPへ分ける。

| ルート | 実行者 | IAM | Identity Domain/OAuth |
|---|---|---|---|
| `infra/orm-v2-admin` | テナンシIAM管理者 | Dynamic GroupとPolicyを新規作成 | 新規Domainまたは権限のある既存Domainに自動作成 |
| `infra/orm-v2-compartment` | 専用コンパートメント管理者 | 既存Dynamic Groupを検査し、Runtime Policyは新規作成 | 専用Domain、public/confidentialアプリを新規作成 |

アプリ基盤は`infra/terraform/modules/orm-v2-stack`に集約し、2つのルート間で構成差が発生しないようにする。

## 設計原則

1. 既存VCN、ADB、バケット、アプリ基盤は再利用しない。
2. 管理者版を除き、既存・共有Identity Domainは利用しない。
3. コンパートメント版でもOAuth機密クライアントをTerraformで作成し、Secretを入力させない。
4. 高度な選択肢は画面へ出さず、動作確認済み値へ固定する。
5. 読み取りAPIで再現可能な判定だけをPlanの事前確認にする。
6. Terraform 1.5.7で動作し、条件付きimportなど新しい機能に依存しない。
7. 大阪とシカゴだけを選択可能にし、未購読ならサブスクライブ方法を表示する。

## 実装段階

### Phase 1 — 2テンプレートと入力削減（実装済み）

- 管理者版4項目、既存Domain利用時だけ5項目
- コンパートメント版4項目（リージョン、コンパートメント、メール、Dynamic Group名）
- コンパートメント版のDynamic Group存在/ACTIVE/Matching Rule検査
- 管理者版はDynamic Group/Policyを新規作成
- コンパートメント版はRuntime Policyだけをコンパートメント内に新規作成
- 専用Identity Domain、SPA用public client、Hosted Agent用confidential clientの自動作成
- 大阪/シカゴ選択とリージョン購読診断
- Generative AI ProjectのTerraform管理
- `jetuse-orm-admin.zip` / `jetuse-orm-compartment.zip`と2つのDeployボタン

### Phase 2 — SQL SearchのTerraform管理（未実装）

構築順序を次に固定する。

1. ADBとWalletを作成
2. 独立した再実行可能な工程で`JETUSE_APP` / `JETUSE_QUERY`とスキーマを作成
3. Vault、KMS Key、ADMIN/JETUSE_QUERY Secretを作成
4. enrichment用とquery用のDatabase Tools接続を作成・検証
5. Semantic Storeを作成
6. SHスキーマのFULL_BUILD enrichmentを開始し、成功まで待機
7. Semantic Store OCIDを渡してAPIコンテナを起動

現行はAPIコンテナ起動後にDBユーザーを作るため、そのままでは
`API → Semantic Store → Database Tools → JETUSE_QUERY → API`の循環になる。
次の条件を満たすDB初期化方式を実機検証してから採用する。

- Resource Manager以外のローカルツールを利用者に要求しない
- 初回Apply一回で完了する
- 再Applyが冪等で、パスワードをログへ出さない
- 初期化失敗時にSemantic Storeとアプリを作り始めない
- DestroyでTerraform管理対象を追跡できる

### Phase 3 — 事前診断の拡張（未実装）

- ADB ECPUなど安定して取得できるサービス上限
- 公開コンテナイメージの対象タグ存在確認
- 同じスタック由来の残存リソース検出
- 新規作成可能/権限不足/サービス上限不足の分類

Policyの継承やより広い権限を読み取りだけで完全判定することはできないため、誤判定する検査は追加しない。

### Phase 4 — 配布と実機ゲート（進行中）

- CIで2ルートと2つのZIPをTerraform最新/LTS 1.5.7の両方でvalidate
- mock providerで管理者/コンパートメントのIAM分離とMatching Rule拒否を検査
- 新規テナンシ、未購読、権限不足、Matching Rule不足、再Apply、Destroyを実機確認
- SQL Searchを含む受け入れ項目合格後に一般利用可能と判定

## 完成判定

- GitHub READMEに権限別のDeployボタンが2つ表示される
- 各入力画面が通常4項目だけである
- コンパートメント版がテナンシレベルのDynamic Group/Policyを作成しない
- コンパートメント版が専用Identity Domainと2種類のOAuthアプリを作成する
- Planエラーが日本語で原因と次の操作を示す
- Generative AI ProjectとSemantic StoreのOCIDがアプリへ直接渡る
- SQL Search enrichmentが成功し、JetUseから問合せできる
- 再Applyに差分がなく、Destroy後に管理対象が残らない
- 既存`jetuse-orm.zip`の内容・挙動を変えない
