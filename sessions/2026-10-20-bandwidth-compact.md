# 帯域・転送時間計算の小窓化

- 利用者指定：容量と時間／速度を上部、結果を下へまとめ、計算方法をタブで切り替えてできるだけコンパクトにする。
- TechnicalCalculatorViewの帯域計算だけCompactBandwidthCalculatorViewへ分岐。標準320×360pt（最小300×320pt）。容量と時間／速度の2行入力、結果の縦スクロール、個別／全体コピー。テーマと理論値の説明は歯車popover。
- 容量・時間・速度の単位、計算API、コピー形式、不正値の理由表示を維持。入力・単位・モード変更でコピー済み表示を解除。他ツールは変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactBandwidth.swiftは隔離UserDefaultsと非表示の実Viewで4テーマ×帯域／転送時間／ゼロ／大数／不正値の20画面描画。build/bandwidth-compact-previewのBlue Cosmos帯域・Windows 98転送時間を目視確認。
- compile対象：VisualTheme、TechnicalCalculators／CSVDocument／BusinessDays、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／TechnicalCalculatorViewとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・タブ切替・単位変更・popover・コピーは未検証。本番配置・起動・終了なし。
