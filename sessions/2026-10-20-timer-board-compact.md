# タイマーボードの小窓化

- 利用者指定：名前・残り時間・開始／一時停止を中心にできるだけコンパクトにする。追加指示の「チャットボタン」は「ちゃんとボタンに」の訂正で、アイコン可。押せる範囲の広い通常ボタンを採用。
- TimerBoardViewを標準320×280pt（最小300×220pt）の縦スクロールへ。各カードは名前／状態／設定と、時間／開始・一時停止／リセットの2段。追加・設定・リセットは28ptのアイコン枠とボタンstyleの余白で押せる範囲を確保。
- 時間・種類・通知・メモ・複製・移動・削除は各設定popover。全体操作とテーマは上部設定へ。設定BindingはIDで対象を探して即保存し、削除・並べ替え後の添字参照を避ける。モデルと既存保存キー、他のタイマー／カレンダーは変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactTimerBoard.swift：隔離UserDefaults、非表示の実TimerBoardViewで4テーマ×空／3個／12個を描画。build/timer-board-compact-previewへ出力。通常320×280、Windows 98はタイトル込み320×310。Blue Cosmos／Windows 98の3個を目視確認。保存復元・上限・削除・複製・並べ替え・全一時停止／リセットも成功。
- compile対象：VisualTheme、UtilityTimer、BusinessDays、CSVDocument、ToolCatalog、AppTheme／Theme*.swift、IndependentTools、ToolDesign、TimerToolsViewとプローブ。swiftc -parse-as-libraryを使用。
- 実画面の物理操作・popoverは未検証。本番への配置・起動・終了なし。
