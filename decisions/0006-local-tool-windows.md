# ローカル5ツールと独立window
Status: Accepted / Date: 2026-10-15

## Context
ユーザーのWebツール5本をMyToolBoxへ追加。メニューの監視表示は残し、ツール集として拡張する。既存0005の入口から利用する。

## Decision
営業日・音声出力・マイク・CSV閲覧・CSV編集を独立Swift実装。新ツールは重複しないNSWindow、監視は既存popoverを維持。ToolPage/ToolCardとツール別色で共通デザイン。音声/マイクは明示開始、録音はメモリ内10秒、close/sleepで停止。CSVは明示保存、未保存closeを確認。公式祝日を同梱し1955〜2027年限定。

## Reason
popover外側クリックで入力が消えることを避け、CSV作業領域を確保する。アプリ実行中は外部通信を不要にする。参照Gitのライセンス不明のためコードや画像は転用せず、仕様だけ参照。

## Alternatives
WebViewで元サイトを表示すると外部依存が残る。HTML/JSのバンドルはライセンス不明で採用しない。全ツールをpopover内へ押し込む方式は編集に不向き。

## Consequences
マイクの用途説明とaudio-input entitlementが追加されるが、許可要求は開始ボタン時のみ。機能差・上限・未検証は[ローカルツール](../docs/LOCAL_TOOLS.md)。将来年の祝日は手動更新。Undo・カレンダー装飾などは初期版の制約。
