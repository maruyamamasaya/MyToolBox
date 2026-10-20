# 比較ツールの小窓・拡大切替

- 利用者指定：最初はコンパクトに開き、拡大／小さく戻すを切り替えられるようにする。入力・結果は保持する。
- ComparisonViewを標準360×520pt（最小340×480pt）、拡大1100×850pt（最小800×600pt）へ。小窓は上下入力・A/B差分の縦並び・リスト結果の縦スクロール。拡大時は左右入力・既存DiffGrid・3列リストを維持。
- ComparisonWindowSizingは自身のresizable windowだけを画面内へサイズ変更。モデルを作り直さず、入力・結果・モードを保持。比較条件・折返し・テーマは歯車へ。入替・クリア・比較・コピーと既存計算は維持。
- Fast・最終Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactComparison.swift：隔離設定・非表示実Viewで4テーマ×差分／リスト×小窓／拡大／小窓を描画し、モデル内容の保持を確認。別の非表示NSWindowで実際のサイズ変更bridgeの360×520→1100×850→360×520を検証。
- 初回compileはLineTools依存不足で失敗、追加後成功。小窓差分の整列も描画で修正し再検証。build/comparison-compact-previewのBlue Cosmos小窓／拡大とWindows 98リスト小窓を目視確認。
- compile対象：VisualTheme、CSVDocument／BusinessDays／TextTools／TextCodec／Comparison／LineTools、ToolCatalog、AppTheme／Theme*.swift、ToolDesign／IndependentTools／TextToolViews／TextCodecView／CSVTool／ComparisonViewとプローブ。swiftc -parse-as-libraryを使用。
- 実画面の切替ボタン・物理操作・小画面・複数画面・popover・コピーは未検証。今回の変更は未コミット・本番未反映。

## 2列表示への追加調整

- 利用者指定で小窓の差分も2列へ統一。A（左）は橙、B（右）は青緑の見出し、中央線、行ごとの状態帯で識別する。変更文字の強調・空行と欠損の区別・折返し切替を維持。
- 小窓の幅に合わせて行番号と余白を縮小し、拡大時は広く表示。短い結果でも上端へ揃える。
- 追加調整の最終Fullと4テーマの再描画・サイズ往復検証を実行。実画面操作と本番反映は引き続き未実施。

## 入力も2列に統一

- 利用者の訂正を受け、小窓の入力欄もA／Bの左右2列に変更。結果と入力の列位置を揃え、拡大時も同じ配置とする。
- 4テーマの小窓／拡大／小窓と非表示のサイズ往復を再検証。Blue Cosmos小窓を目視確認。モデルの入力・比較結果保持を再確認。本番未反映。
