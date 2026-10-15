# 初期5ツールとUI刷新
Date: 2026-10-15

## Request
WebツールをGitの中身から確認してローカル化。営業日・オーディオ・マイク・CSV閲覧・CSV編集の5本。途中フィードバック「UIが弱い」に対応して画面を全面的に整理。

## Changes
- 参照Gitを浅いclone、対象app.js/index/testを検索して確認。revision/license/差分は[LOCAL_TOOLS](../docs/LOCAL_TOOLS.md)。コード・画像のコピーなし。
- 純粋処理をMonitorKit/Tools、UI・装置操作をMyToolBox/Toolsへ分離。独立window、閉じる/sleepで音声停止、CSV未保存の確認。
- 内閣府祝日1955〜2027年同梱。CSVは引用符・改行・空セル・UTF8/ShiftJIS、上限あり。マイクは明示許可・メモリ内10秒のみ。
- ToolPage/ToolCardで共通デザイン。2列の色別ツール一覧、月カレンダーと営業日数、左右スピーカーカード、マイクレベルメーター、CSV空状態/表/編集/保存の整理。
- 既存の数値メニュー・監視・定期ログ・設定を維持。/Applicationsをバックアップして更新、最終更新は通常終了を経由（未保存時に強制停止しない）。

## Validation
- Fast/Full成功、Swift単体33件、文書verify負例3件、Xcode Release・.app・codesign成功。
- マイク用途説明・audio-input entitlement・祝日1067件の同梱確認。
- evidence/tool-*.pngで6画面をオフスクリーン描画（CSVは合成データ、音声未開始）。一部オフスクリーン描画の文字に残像があったため実画面も確認。
- 実機CUAは途中pipe切断/timeout、再接続後に一覧→営業日を操作。「今日から1週間」で2026/10/15〜10/21、期間7・土日2・営業日5を確認。カレンダーの実画面に重なりなし。音声画面はAXで操作欄確認。
- 更新後loginStatus=1、設定の再登録なし。

## Remaining
音の左右・装置ルーティング、マイク許可/実録音、CSVのUI編集保存/再読込、独自休日UI、装置切替/sleep、長時間、再ログイン、Parallels比較は未検証。手順/合否基準はLOCAL_TOOLSと既存移行チェックリスト。Undo、カレンダー連続範囲表示、2028年以降の祝日は未対応。
