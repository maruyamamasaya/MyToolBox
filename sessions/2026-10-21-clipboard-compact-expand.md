# クリップボード整形の小窓・拡大

- 利用者指定：最初はコンパクト、拡大／小さく戻すで切替。表とリストの内容を保持する。
- ClipboardWorkspaceViewを標準360×520pt（最小340×480pt）、拡大1100×850pt（最小800×600pt）へ。実CSVGridの編集、入力・結果・列選択・形式・囲み・清掃条件・リスト全条件・他モード入力の引継ぎ・貼付け／クリア／整形／コピーを維持。設定は歯車へ。
- 拡縮とモード切替前にtable.finishEditingを実行。モデルは継続保持し、両モデルの変更監視をworkspaceに配置。入力変更以外の拡縮だけでは再parseしない。表copyの最新編集確定処理も維持。
- 比較ツールのサイズ変更bridgeをExpandableToolWindowSizingとしてToolDesignへ共通化し、比較側と検証プローブの参照を更新。サイズ変更の実装ロジックは維持。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactClipboard.swiftは実表モデルをparse後、セル編集による出力反映を確認。隔離設定・非表示実Viewで4テーマ×表／リスト×小窓／拡大／小窓を描画し、表の編集・両モデル出力の保持を検証。非表示NSWindowでサイズ往復も成功。
- build/clipboard-compact-previewのBlue Cosmos表の小窓／拡大、Windows 98リスト小窓を目視確認。
- compile対象：VisualTheme、CSVDocument／BusinessDays／TextTools／TextCodec／LineTools／StringReplacer／ListConverter、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／IndependentTools／TextToolViews／TextCodecView／CSVTool／LineToolViews／ReplacerViewとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・未確定セルの物理編集からの拡縮・設定popover・コピーは未検証。今回の変更は未コミット・本番未反映。
