# テキストクリーナーの小窓化

- 利用者指定：3モードをタブ、入力と結果を上下へ配置してできるだけコンパクトにする。
- TextCleanerViewを標準340×360pt（最小320×340pt）へ。貼付け／クリア／実行／コピーを常設。テーマと既存処理の説明は歯車へ。元々変更可能な処理オプションはないため、新たな設定は追加していない。
- TextTransformModelの自動更新・キャンセル・文字数・エラー・入力制限と既存処理は維持。他の連番・表整形等は変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。検証器8件成功。
- tools/RenderCompactTextCleaner.swiftは実モデルで処理後、隔離UserDefaults・非表示Viewで4テーマ×クリーニング／可視化／文字チェック／空入力の16画面描画。build/cleaner-compact-previewのBlue Cosmosクリーニングを目視確認。
- compile対象：VisualTheme、CSVDocument／BusinessDays／TextTools／TextCodec、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／IndependentTools／TextToolViews／TextCodecView／CSVToolとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・モード切替・popover・コピーは未検証。本番反映は一括配置記録を参照。
