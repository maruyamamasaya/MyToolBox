# ポモドーロの小窓化

- 利用者が乱数の小窓を了承し、ポモドーロもできるだけ小さくするよう依頼。
- FocusTimerViewのポモドーロだけCompactPomodoroViewへ分岐。標準260×210pt、最小幅240pt。会議タイマー・カレンダー・モデルの計測処理は変更なし。
- 集中／休憩・今日の回数・残り時間・進捗・状態・開始／一時停止／リセットを常時表示。1時間未満はmm:ss、長時間はhh:mm:ss。時間設定とテーマは歯車のpopoverへ。実行中の時間設定禁止は従来通り。
- Fast・Full成功（Swift単体、Releaseビルド、codesign、55helper検証）。検証器8件成功。diff check成功。
- tools/RenderCompactPomodoro.swift：本番と同じFocusTimerViewを隔離UserDefaultsと非表示NSWindowで4テーマ×準備／計測／一時停止／休憩／3時間の20画面描画。build/pomodoro-compact-previewへ出力。通常260×210、Windows 98はタイトル込み260×240。Blue Cosmos準備／長時間・Windows 98休憩を目視確認。
- プローブのcompile対象：VisualTheme、UtilityTimer、BusinessDays、CSVDocument、ToolCatalog、AppTheme／Theme*.swift、IndependentTools、ToolDesign、TimerToolsViewとプローブ。swiftc -parse-as-libraryを使用。
- 実画面の物理操作・設定popoverは未検証。本番への配置・起動・終了なし。
