# 会議タイマーの小窓化

- 利用者がポモドーロの小窓を了承し、会議タイマーも同様にできるだけ小さくするよう依頼。
- FocusTimerViewの会議分岐をCompactMeetingTimerViewへ変更。不要になった旧大型Viewとポモドーロの旧分岐を除去。モデル・計測・カレンダーは変更なし。
- 標準260×210pt、最小幅240pt。15／30／45／60／90分の選択、残り時間、進捗、開始／一時停止、リセット。計測中は終了予定時刻。カスタム時分秒とテーマは歯車popover。実行中の時間選択禁止・経過ありのカスタム編集禁止・ゼロ時間の開始禁止を維持。
- Fast・Full成功（Swift単体、Releaseビルド、署名、55helper検証）。diff check成功。
- tools/RenderCompactMeeting.swiftは実FocusTimerViewを隔離UserDefaults・非表示NSWindowで4テーマ×準備／計測／一時停止／終了／カスタム／ゼロ／最大時間の28画面描画。build/meeting-compact-previewへ出力。通常260×210、Windows 98はタイトル込み260×240。Blue Cosmos準備／最大時間・Windows 98計測中を目視確認。
- compile対象はポモドーロと同じ（VisualTheme、UtilityTimer、BusinessDays、CSVDocument、ToolCatalog、AppTheme／Theme*.swift、IndependentTools、ToolDesign、TimerToolsViewとプローブ）。swiftc -parse-as-libraryを使用。
- 実画面の物理操作・設定popoverは未検証。本番の配置・起動・終了なし。
