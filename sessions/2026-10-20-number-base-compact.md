# 進数変換の小窓化

- 利用者指定：容量変換と同様、数値・入力基数を上部、変換結果を下へまとめ、できるだけコンパクトにする。
- TechnicalCalculatorViewの進数変換だけCompactNumberBaseConverterViewへ分岐。標準320×360pt（最小300×300pt）。入力と2〜60の基数選択を1行に配置。
- 2・10・12・16・24・60進数と追加基数への出力を維持。追加基数・テーマ・説明は歯車popover。個別／全体コピーを維持し、長い結果でも基数名とコピーを行頭上部へ揃える。入力・基数変更でコピー済み表示を解除。
- 計算API・整数精度・1024桁制限・入力形式・他ツールは変更なし。
- Fast・最終Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactNumberBase.swift：実Viewを隔離UserDefaults・非表示NSWindowで4テーマ×10進／負の16進／ゼロ／200桁／不正入力／60進の24画面描画。build/base-compact-previewのBlue Cosmos通常／長整数とWindows 98負数を目視確認。長整数でボタンが中央下方へ隠れる初回描画を修正し再描画。
- compile対象：VisualTheme、TechnicalCalculators／CSVDocument／BusinessDays、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／TechnicalCalculatorViewとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・スクロール・popover・コピーは未検証。本番配置・起動・終了なし。
