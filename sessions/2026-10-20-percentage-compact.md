# 割合計算の小窓化

- 利用者指定：計算方法をタブで切り替え、入力と結果を中心にできるだけコンパクトにする。
- EverydayCalculatorViewの割合だけCompactPercentageCalculatorViewへ分岐。標準320×360pt（最小300×320pt）。増減率／割合／○%計算／逆算、2入力、結果スクロール、個別／全体コピー、クリアを維持。テーマと説明は歯車popover。
- 計算API・全角／通貨／%付き入力・モード別入力保持・分母ゼロ等の理由表示を維持。入力とモード変更でコピー済み表示を解除。他ツールは変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactPercentage.swiftは隔離UserDefaults・非表示実Viewで4テーマ×増減率／割合／○%計算／逆算／分母ゼロ／不正入力の24画面描画。build/percentage-compact-previewのBlue Cosmos増減率・Windows 98逆算を目視確認。
- compile対象：VisualTheme、EverydayCalculators／CSVDocument／BusinessDays、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／EverydayCalculatorViewsとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・タブ切替時の入力保持・popover・スクロール・コピーは未検証。本番配置・起動・終了なし。
