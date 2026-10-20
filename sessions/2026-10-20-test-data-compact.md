# テストデータ生成の小窓化

- 利用者指定：文章・文字列・CSV・UUIDをタブで切り替え、必要な条件を表示し、生成・コピーを常設してできるだけコンパクトにする。
- TestDataGeneratorViewを標準340×340pt（最小320×300pt）へ。タブ・条件要約・条件変更・結果スクロール・生成／コピー／クリア。モード別設定はスクロール付きpopoverへ移動。
- 文字列の条件を縦配置、CSVの型選択幅を125ptへ。生成API・全条件・入力制限・既存GeneratorModel・条件変更による旧結果解除、UUID個別コピーを維持。ハッシュ等は変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactTestData.swiftは隔離UserDefaults・非表示実Viewで4テーマ×文章／文字列／CSV／UUID／未生成の20画面描画。出力は実GeneratorModelと生成APIで生成。build/test-data-compact-previewのBlue Cosmos文字列、Windows 98 UUIDを目視確認。
- compile対象：VisualTheme、DeveloperGenerators／CSVDocument／BusinessDays／TextTools／TextCodec、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／IndependentTools／DeveloperGeneratorView／TextToolViews／TextCodecView／CSVToolとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・タブ／条件変更・設定popover・スクロール・コピーは未検証。本番配置・起動・終了なし。
