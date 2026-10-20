# 数値集計の小窓化

- 利用者指定：入力欄と合計・平均を中心に、他の集計値を下にまとめてできるだけコンパクトにする。集計・コピーは押しやすくする。
- EverydayCalculatorViewの数値集計だけCompactNumberSummaryViewへ分岐。標準320×380pt（最小300×340pt）。入力欄70pt、集計／クリア、スクロールする結果、個別／全体コピー。
- 合計・平均を大きめに、件数・最大・最小・中央値・範囲も維持。不正トークンの除外件数と先頭20件を維持。計算API・区切り規則・20,000件／500KB上限、入力変更による旧結果解除は従来どおり。テーマと説明は歯車へ。他ツールは変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactNumberSummary.swiftは隔離UserDefaults・非表示実Viewで4テーマ×未集計／標準／不正値混在／数値なし／桁溢れの20画面描画。描画するSummaryも本番のsummarizeで生成。build/number-summary-compact-previewのBlue Cosmos標準・Windows 98除外案内を目視確認。
- compile対象：VisualTheme、EverydayCalculators／CSVDocument／BusinessDays、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／EverydayCalculatorViewsとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・再集計・popover・スクロール・コピーは未検証。本番配置・起動・終了なし。
