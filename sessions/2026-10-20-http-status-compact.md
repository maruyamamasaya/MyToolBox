# HTTPステータス一覧の小窓化

- 利用者指定：ポート検索同様、検索・分類を上部、コード・名前・説明を下へまとめてできるだけコンパクトにする。
- NetworkReferenceViewのHTTP側をCompactHTTPStatusViewへ分岐し、不要になった旧大型Viewを削除。ポート側の小窓は維持。標準320×360pt（最小300×320pt）。
- 検索／クリア、分類、件数、色分けしたコード・英語名・日本語説明を縦スクロール。52件のデータ、検索API、番号／説明付きコピー、0件案内を維持。テーマと説明は歯車へ。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactHTTPStatus.swiftは隔離UserDefaults・非表示実Viewで4テーマ×全件／404／2xx／認証／0件の20画面描画。build/http-compact-previewのBlue Cosmos全件・Windows 98の404を目視確認。
- compile対象：VisualTheme、NetworkReference／CSVDocument／BusinessDays、AppTheme／Theme*.swift、ToolDesign／NetworkReferenceViewとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・検索／分類切替・popover・スクロール・コピーは未検証。本番配置・起動・終了なし。
