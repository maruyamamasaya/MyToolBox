# ポート番号検索の小窓化

- 利用者が検索・分類を上部、番号・用途を一覧にする小窓案を了承。
- NetworkReferenceViewのポート側だけCompactPortReferenceViewへ分岐。標準320×360pt（最小300×320pt）。検索／クリア、TCP／UDP、件数、番号・サービス名・用途の縦スクロール。
- よく使う8ポートは上部メニューへ移動し、選択時のフィルター解除を維持。番号／説明付きコピーは枠付きメニュー。説明とテーマは歯車へ。検索と絞り込み変更でコピー状態表示解除。
- 既存PortReference API・43件のデータ・検索規則・通信なしを維持。HTTPステータス一覧は変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactPortReference.swiftは隔離UserDefaults・非表示実Viewで4テーマ×全件／443／UDP／database／0件の20画面描画。build/port-compact-previewのBlue Cosmos全件・Windows 98の443を目視確認。
- compile対象：VisualTheme、NetworkReference／CSVDocument／BusinessDays、AppTheme／Theme*.swift、ToolDesign／NetworkReferenceViewとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・検索／絞込切替・popover・スクロール・コピーは未検証。本番配置・起動・終了なし。
