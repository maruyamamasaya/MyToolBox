# ハッシュ生成の小窓化

- 利用者指定：ハッシュ生成をできるだけコンパクトにする。押しやすい枠付きボタンの希望も継承。クイックメモは広いまま維持。
- HashGeneratorViewを標準320×360pt（最小300×340pt）へ。SHA／HEX・Base64選択、入力、貼付け／クリア／生成／コピー、結果、状態の順。入力と結果は欄内スクロール、テーマと説明は歯車popover。
- 計算モデル、UTF-8・1MiB制限、空文字対応、設定／入力変更時の無効化とコピー禁止は維持。テストデータ生成や他ツールは変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactHash.swiftは実GeneratorModel／HashGeneratorViewを隔離UserDefaults・非表示NSWindowで4テーマ×未生成／SHA-256／SHA-512／Base64／上限エラーの20画面描画。エラー画面はモデルに上限超過結果を与えた合成状態。build/hash-compact-previewのBlue Cosmos SHA-256／512とWindows 98エラーを目視確認。
- 描画プローブの初回compileは依存CSVTool不足で失敗し、追加後成功。compile対象：VisualTheme、DeveloperGenerators／CSVDocument／BusinessDays／TextTools／TextCodec、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／IndependentTools／DeveloperGeneratorView／TextToolViews／TextCodecView／CSVToolとプローブ。swiftc -parse-as-libraryを使用。
- 実画面の物理操作・popover・クリップボードは未検証。本番配置・起動・終了なし。
