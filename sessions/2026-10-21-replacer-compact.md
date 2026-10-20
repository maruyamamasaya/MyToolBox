# 検索・置換の小窓化

- 利用者指定：検索・置換文字を上部、入力・結果を上下に配置し、正規表現と複数ルールを歯車へまとめてできるだけコンパクトにする。
- ReplacerViewを標準360×440pt（最小340×400pt）へ。4モード、複数行対応の検索／置換欄、入力・結果、貼付け／クリア／結果を入力へ／実行・中止／コピーを維持。
- 一致箇所はハイライトpopoverへ。正規表現・各一致条件・複数ルール・複数削除を条件popoverへ。モデルと計算API、ICU／制限／実行後のみコピー可の既存仕様は維持。他ツールは変更なし。
- Fast・最終Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactReplacer.swiftは実モデルで処理後、隔離UserDefaults・非表示実Viewにより4テーマ×検索／置換／削除／複数ルール／不正regexの20画面描画。初回確認後に入力・結果の見出しと背景を追加し再描画。build/replacer-compact-previewのBlue Cosmos置換と初回Windows 98複数ルールを目視確認。
- compile対象はRenderCompactLineToolsと同じ依存にReplacerView.swiftを追加。swiftc -parse-as-libraryを使用。
- 実画面操作・条件／一致箇所popover・キャンセル・コピーは未検証。今回の変更は未コミット・本番未反映。
