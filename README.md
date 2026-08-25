# JetUse on OCI — 生成AIユースケース基盤（Public版）

OCI Enterprise AI（OpenAI互換 agentic API）を基盤に、チャット / ユースケース / RAG / DBチャット(NL2SQL) /
エージェント / 音声 / 画像・映像分析を1つのWebアプリにまとめたプロトタイプ。すべてOCIのマネージドサービス上で動く。

[English README](./README.en.md)

## デプロイ

### テナンシIAM管理者向け

[![Deploy JetUse as a tenancy IAM administrator](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/sogawa-yk/jetuse/releases/download/orm-main/jetuse-orm-admin.zip)

Dynamic Group、Runtime Policy、専用Identity Domain、公開/機密OAuthアプリを含め、すべて新規作成する。

### コンパートメント管理者向け

[![Deploy JetUse as a compartment administrator](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/sogawa-yk/jetuse/releases/download/orm-main/jetuse-orm-compartment.zip)

テナンシ管理者がDynamic Groupとデプロイ権限を準備済みの場合に使用する。Terraformは
Dynamic Groupの存在・状態・Matching RuleをPlanで検査し、コンパートメント内のRuntime Policy、
専用Identity Domain、ログイン用公開クライアント、Hosted Agent用機密クライアントを自動作成する。
既存Identity Domain、Client ID、Client Secretの入力は不要。

どちらも大阪またはシカゴを選択できる。未購読ならOCIコンソールの「リージョン管理」で
サブスクライブしてからPlanを再実行する。VCN / Autonomous Database / API Gateway /
Container Instance / Functions / Object Storageを新規作成し、初回は10〜15分。

- 管理者版の入力: リージョン、対象コンパートメント、管理者メール、Identity Domainの新規/既存。
- コンパートメント版の入力: リージョン、対象コンパートメント、管理者メール、管理者作成済みDynamic Group名。
- 2テンプレートの選び方と事前IAM設定は [ORM v2ガイド](./docs/setup/orm-v2.md)。
- 従来の詳細入力版は [Resource Managerガイド](./docs/setup/orm.md)。

## 機能

| 領域 | 機能 |
|---|---|
| チャット | ストリーミング会話、モデル選択、パラメータ/プリセット、短期メモリ、Markdown/Mermaid表示 |
| ユースケース | フォーム+プロンプトテンプレートの定義・共有（ビルダー）、組み込み5種 |
| RAG | 文書アップロード→引用付き回答（Vector Store / Select AI の2バックエンド） |
| DBチャット | 自然言語→SQL生成・実行（SQL Search / Select AI）、結果のグラフ化 |
| エージェント | ツール実行・MCP・記憶分離。エンジンは native / OpenAI Agents SDK（既定） / LangGraph |
| 音声 | 議事録（話者分離）、リアルタイム文字起こし、音声チャット（半二重） |
| マルチモーダル | 画像入力チャット、動画フレーム分析 |
| 管理・運用 | 監査ログ・利用ダッシュボード、入力モデレーション、レート制限、OCI Logging/Monitoring連携 |

## アーキテクチャ

- **フロント**: React SPA（Object Storage静的配信 + API Gateway、HashRouter）
- **API**: SSE系=Container Instance（FastAPI） / 非ストリーミング=OCI Functions（ADR-0005）
- **AI**: OCI Enterprise AI（OpenAI互換 Responses/Chat Completions、IAM署名）
- **データ**: ADB 26ai（会話・定義・議事録・NL2SQL）、Object Storage（文書・音声・ウォレット）
- **認証**: IAM Identity Domain（OIDC + PKCE）。SAMLフェデレーション手順あり

詳細とMermaid図 → [docs/architecture/system.md](./docs/architecture/system.md)

## 開発

初回セットアップから自分専用のE2E環境までは [オンボーディングガイド](./docs/guides/onboarding.md)。

```bash
cd packages/api && AUTH_REQUIRED=false uvicorn service.main:app --port 8000  # API（認証オフ）
cd packages/web && VITE_AUTH_REQUIRED=false npm run dev                     # SPA（/api を :8000 へ）

make lint && make test && make build   # コミット前チェック（入口は root Makefile・一覧は make help）
make deploy DEV=<名>                    # 自分専用のOCI環境へ配備してE2E
```

```
packages/web/    React SPA
packages/api/    FastAPI(service/) + Functionsルーター(fn/) + 共有ロジック(jetuse_core/)
infra/           terraform/(モジュールと環境) + orm/(ワンクリックスタック)
docs/            設計・ADR・検証レポート・運用ガイド
specs/           機能仕様（フェーズごと）
```

ブランチは `main`（Public安定版・Deployボタンの配信元）/ `public-dev`（Public統合）/
`internal-dev` / `internal-stable`。Publicの変更は `public-dev` へ入れ、リリース時に `main` へ運ぶ
（[ブランチとリリース](./docs/guides/branching-and-releases.md)）。検証は実機確認主義（結果は `docs/verification/`）。

## ドキュメント

目次は [docs/README.md](./docs/README.md)。よく見るもの:

| 知りたいこと | 参照 |
|---|---|
| 全体設計・図 | [docs/architecture/system.md](./docs/architecture/system.md) |
| 設計判断の理由 | [docs/decisions/](./docs/decisions/)（ADR） |
| 方式選定（RAG/NL2SQL/エージェントFW/コンピュート） | [docs/comparison/](./docs/comparison/) |
| カスタマイズ方法 | [docs/guides/customize.md](./docs/guides/customize.md) |
| デモ台本 | [docs/guides/demo-scenarios.md](./docs/guides/demo-scenarios.md) |
| 実機ハマり集 | [docs/tips.md](./docs/tips.md) |
