# RAID計算の小窓化

- 利用者指定：RAIDレベル・台数・1台容量を上部、容量・効率・耐障害性を下へまとめ、できるだけコンパクトにする。
- TechnicalCalculatorViewのRAIDだけCompactRAIDCalculatorViewへ分岐。標準320×360pt（最小300×320pt）。入力とGB／TB選択、結果の縦スクロール、個別／全体コピー。テーマと従来の前提説明は歯車popover。
- RAID 0／1／5／6／10、計算API、最大台数・構成制約、コピー形式を維持。耐障害性は省略せず折返し。入力変更でコピー済み表示を解除。他ツールは変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactRAID.swiftは隔離UserDefaults・非表示実Viewで4テーマ×RAID5／0／1／6／10／不正台数／容量ゼロの28画面描画。build/raid-compact-previewのBlue Cosmos RAID5、Windows 98 RAID10を目視確認。
- compile対象：VisualTheme、TechnicalCalculators／CSVDocument／BusinessDays、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／TechnicalCalculatorViewとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・設定変更・popover・スクロール・コピーは未検証。本番配置・起動・終了なし。
