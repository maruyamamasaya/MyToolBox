# SLA計算の小窓化

- 利用者指定：稼働率とプリセットを上部、期間別の停止可能時間を下へまとめ、できるだけコンパクトにする。
- TechnicalCalculatorViewのSLAだけCompactSLACalculatorViewへ分岐。標準320×360pt（最小300×320pt）。稼働率入力・99／99.9／99.99／99.999%のプリセット選択を1行にまとめる。
- 日・週・30日月・365日年の結果と個別／全体コピーを維持。テーマと計算式・丸めの説明は歯車popover。計算API、0〜100%の制約、コピー形式は維持。入力変更でコピー済み表示を解除。他ツールは変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactSLA.swift：隔離UserDefaults・非表示実Viewで4テーマ×99.9／99.999／100／0／不正値／範囲外の24画面描画。build/sla-compact-previewのBlue Cosmos標準・Windows 98の99.999%を目視確認。
- compile対象：VisualTheme、TechnicalCalculators／CSVDocument／BusinessDays、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／TechnicalCalculatorViewとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・プリセット切替・popover・スクロール・コピーは未検証。本番配置・起動・終了なし。
