# 容量変換の小窓化

- 利用者指定：数値と単位を上部、変換結果を下へまとめ、できるだけコンパクトにする。押しやすいボタンの希望を継承。
- TechnicalCalculatorViewの容量変換だけCompactByteConverterViewへ分岐。標準320×360pt（最小300×300pt）。9単位を縦スクロール、各行コピー・全体コピーを維持。テーマと説明は歯車popover。
- 自動読取／手動単位指定、倍率、計算と近似表示は既存TechnicalCalculators APIのまま。入力・単位の変更でコピー済み表示を解除。他4計算ツールとカレンダー／メモは変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactByteConverter.swift：実CompactByteConverterViewを隔離UserDefaults・非表示NSWindowで4テーマ×自動／KiB手動／ゼロ／大数／不正入力の20画面描画。build/byte-compact-previewのBlue Cosmos自動・Windows 98手動を目視確認。
- compile対象：VisualTheme、TechnicalCalculators／CSVDocument／BusinessDays、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／TechnicalCalculatorViewとプローブ。swiftc -parse-as-libraryを使用。
- 実画面の物理操作・スクロール・popover・コピーは未検証。本番配置・起動・終了なし。
