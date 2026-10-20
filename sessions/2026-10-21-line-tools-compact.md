# 行ツールの小窓化

- 利用者指定：3機能をタブで切り替え、入力と結果を上下に配置し、条件を歯車へまとめてできるだけコンパクトにする。
- LineToolsViewを標準360×400pt（最小340×360pt）へ。貼付け／クリア／結果を入力へ／実行／コピーを常設。条件は縦配置のスクロール付きpopover。抽出条件の追加・削除、元の順番・再開、重複の回数・元行番号を維持。
- LineToolModel、計算API、入力共有、自動処理、キャンセル、上限、コピー形式と条件変更時の元順解除を維持。他のリスト変換等は変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactLineTools.swiftは隔離UserDefaults・非表示実Viewで4テーマ×並べ替え／行抽出／重複／空入力の16画面描画。実モデルのupdate完了後に描画。build/lines-compact-previewのBlue Cosmos並べ替え・Windows 98重複を目視確認。
- compile対象：VisualTheme、CSVDocument／BusinessDays／TextTools／TextCodec／LineTools／StringReplacer／ListConverter、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／IndependentTools／TextToolViews／TextCodecView／CSVTool／LineToolViewsとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・条件popover・コピーは未検証。今回の変更は未コミット・本番未反映。
