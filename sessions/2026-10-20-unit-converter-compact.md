# 単位変換の小窓化

- 利用者指定：カテゴリ・変換元／先を上部、数値と結果を下へまとめ、入れ替えとコピーを押しやすく残してできるだけコンパクトにする。
- EverydayCalculatorViewの単位変換だけCompactUnitConverterViewへ分岐。標準320×340pt（最小300×320pt）。カテゴリ、単位選択と入替、数値／クリア、結果と換算式、個別／全体コピー。
- 小数桁0〜10、テーマ、説明は歯車popover。全10カテゴリ・1000／1024倍切替・手入力の通貨レート・レート逆数による単位入替・計算API・カテゴリ変更時の単位／レート初期化を維持。入力変更でコピー済み表示を解除。他ツールは変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactUnitConverter.swiftは隔離UserDefaults・非表示の実Viewで4テーマ×全10カテゴリの40画面描画。build/unit-compact-previewのBlue Cosmos長さ／データ容量、Windows 98通貨を目視確認。通貨は検証用の合成レートであり実相場ではない。
- compile対象：VisualTheme、EverydayCalculators／CSVDocument／BusinessDays、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／EverydayCalculatorViewsとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・カテゴリ／単位切替・入替・popover・コピーは未検証。本番配置・起動・終了なし。
