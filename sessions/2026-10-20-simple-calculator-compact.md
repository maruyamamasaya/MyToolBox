# シンプル電卓の小窓化

- 利用者指定：計算式と大きな結果を中心にできるだけコンパクトにし、履歴を必要時だけ開く。計算・コピーは押しやすくする。
- EverydayCalculatorViewの電卓だけCompactSimpleCalculatorViewへ分岐。標準300×240pt（最小280×220pt）。入力に結果が追従し、計算ボタン／Enterで履歴へ追加。履歴popoverにコピーと消去を維持。
- コピーは値のみを主ボタン、従来の結果ラベル付き形式は歯車内へ。テーマと演算の説明も歯車へ。クリアは枠付きアイコン。計算API・1000文字上限・演算子・履歴寿命を維持。式変更でコピー済み表示解除。他ツールは変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactSimpleCalculator.swift：隔離UserDefaults・非表示実Viewで4テーマ×標準／括弧／指数／不正式／ゼロ除算の20画面描画。build/simple-calculator-compact-previewのBlue Cosmos標準、Windows 98不正式を目視確認。
- compile対象：VisualTheme、EverydayCalculators／CSVDocument／BusinessDays、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／EverydayCalculatorViewsとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・Enter・履歴追加とpopover・コピーは未検証。本番配置・起動・終了なし。
