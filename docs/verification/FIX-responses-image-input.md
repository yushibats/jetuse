# 検証レポート: Responses 系 vision モデルで画像つき発話が 400 になる不具合

- 対象: `packages/api/jetuse_core/chat.py` の `_to_responses_input()`
- 発見: 2026-09-17、Public版（main `e8e2cc9`）を別コンパートメント / us-chicago-1 へ配備した環境で、
  映像分析（`/video`）に Gemini 2.5 Flash を選んで「分析」を押した
- 症状: 分析結果に次のエラーが出る

  ```text
  Error code: 400 - {'error': {'message': 'Invalid JSON data: Failed to deserialize the JSON body
  at input: data did not match any variant of untagged enum ResponseInput', ...}}
  ```

## 結論: 画像パーツを文字列前提の input_text に入れていた

映像分析と画像チャット（MM-01）は、最終 user 発話を Chat Completions 形式の content パーツ
（`{"type":"text"}` と `{"type":"image_url","image_url":{"url":...}}`）で組み立てる
（`service/routes/chat.py` の `req.images` 分岐）。

Responses 系モデルへ送る前に通す `_to_responses_input()` は `content` を文字列とみなし、
パーツのリストをそのまま `{"type":"input_text","text": <list>}` に入れていた。
Responses API はこれを `ResponseInput` として解釈できず 400 を返す。

AGT-06（2026-08-03）で gemini-2.5-* が Responses 系に登録され、grok-4.* も vision つきで
Responses 系にある。MM-01（2026-06-15）の検証時は gemini が Chat Completions 経由だったため、
この経路は通っていなかった。複数画像を受け付けるモデル（`multi_image=True`）はすべて Responses 系なので、
映像分析はモデルを変えても回避できなかった。

## 修正

`_to_responses_input()` で content がリストのときはパーツごとに変換する。

| 入力パーツ | 送るパーツ |
|---|---|
| `{"type":"text","text":...}`（`input_text` も同様） | `{"type":"input_text","text":...}` |
| `{"type":"image_url","image_url":{"url":...}}` | `{"type":"input_image","image_url":<url>}` |
| `{"type":"input_image",...}` | そのまま |
| その他 | `ValueError`（黙って落とさない） |

文字列の content は従来どおり `input_text` 1 パーツにする（gpt-oss などの既存経路は変えない）。

## 実機での確認（us-chicago-1、ユーザープリンシパル、`POST /openai/v1/responses`）

32×32 の単色 PNG を data URL で渡し「この画像は何色？一語で」と聞いた。

| モデル | 修正前の形（input_text にパーツのリスト） | 修正後の形（input_text + input_image） |
|---|---|---|
| `google.gemini-2.5-flash` | 400 | 200「青」 |
| `xai.grok-4.3` | 400 | 200「青」 |
| `google.gemini-2.5-flash`（画像 2 枚） | — | 200「赤」 |

配備済み環境（us-chicago-1）でも、修正を入れた API イメージへ差し替えた後、映像分析
（Gemini 2.5 Flash、6 フレーム）が分析結果を返すことを画面で確認した（2026-09-18）。

## テスト

- `tests/test_chat.py` に 2 件追加（画像パーツの変換、未知パーツの拒否）
- `packages/api` の pytest 全件 PASS、ruff PASS
