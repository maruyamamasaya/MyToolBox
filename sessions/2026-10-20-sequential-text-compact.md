# 連番テキスト生成の小窓化

- 利用者指定：入力と結果を上下に配置し、番号の設定を歯車にまとめてできるだけコンパクトにする。
- SequentialTextViewを標準340×360pt（最小320×340pt）へ。貼付け・クリア・生成・コピーを常設。開始・増加数・桁数・位置・前後文字・区切り・空行対象・テーマを歯車へ。
- 既存TextTransformModelの自動生成とキャンセル、負数／0・空行・文字数・入力制限・エラー処理を維持。元の桁数UIは1〜8を維持。他ツールは変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactSequentialText.swiftは隔離UserDefaults・非表示実Viewで4テーマ×標準／負数ゼロ埋め／末尾／不正開始値／空入力の20画面描画。実モデルのupdate完了後に描画。build/sequential-compact-previewのBlue Cosmos標準・Windows 98負数を目視確認。
- compile対象：VisualTheme、CSVDocument／BusinessDays／TextTools／TextCodec、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／IndependentTools／TextToolViews／TextCodecView／CSVToolとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・設定popover・コピーは未検証。今回の変更は未コミット・本番未反映。前回までの21ツールの配置は維持。
