# 画像リサイズの小窓・拡大

- 利用者指定：最初はコンパクト、拡大／小さく戻すを切り替え、画像と設定を保持する。
- ImageResizerViewを標準360×560pt（最小340×520pt）、拡大1100×850pt（最小800×600pt）へ。小窓はプレビュー中心、拡大は左プレビュー・右サイズ設定。元画像／変換後のプレビュー切替を追加。
- 幅・高さ・比率・形式、画像選択・リサイズ・保存を常設。倍率とJPEG品質・説明は歯車、一括結果と保存先を開く操作は結果popoverへ。
- 共通ExpandableToolWindowSizingへ小窓サイズの引数を追加（既定は従来の360×520）。比較／クリップボードの既定値は維持。画像は360×560を指定。
- モデル・処理・寸法Binding・一括倍率／ピクセル指定・JPEG品質・元画像保護・複数drop・保存パネルは維持。拡縮だけではモデルを作り直さない。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactImageResizer.swiftは合成PNGを実モデルで読み込み、比率変更・JPEG変換・保存／再読込・元画像の一致、一括2枚の実保存を検証。隔離設定・非表示実Viewで4テーマ×単一／一括×小窓／拡大／小窓を描画し、出力・寸法・一括結果の保持を確認。非表示ウィンドウのサイズ往復も成功。
- build/image-compact-previewのBlue Cosmos単一小窓／拡大、Windows 98一括小窓を目視確認。画像は検証用図形。
- compile対象：VisualTheme、CSVDocument／BusinessDays／ImageResizer、AppTheme／Theme*.swift、ToolDesign／ImageResizerViewとプローブ。swiftc -parse-as-libraryを使用。
- 実画面の拡縮・ファイルパネル・drop・設定popoverは未検証。本番未反映・未コミット。他の作業中変更は保持。
