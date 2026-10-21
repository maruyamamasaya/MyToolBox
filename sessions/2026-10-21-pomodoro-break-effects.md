# ポモドーロの休憩演出

## Request / Investigation
休憩開始の短い青い花火、目を休める案内、休憩終了の控えめな通知を実装。既存FocusTimerModelの手動区間開始とDate計測を確認。

## Changes / Files Changed
- TimerToolsView.swift：休憩初回開始の約3秒のCanvas花火、淡い休憩背景・案内、終了時の約2秒の枠。再開では花火を繰り返さず、リセットで演出状態を消去。
- 花火／終了の光の保存設定と、初期オフの休憩終了音を追加。OSの視差効果低減時は花火・光なし。外部通信・追加素材・依存なし。
- RenderCompactPomodoro.swift：隔離モデルで区間遷移・再開・リセット・設定復元を検証し、実Viewの4テーマ×8状態を非表示描画。
- docs/TIME_TOOLS.md：演出仕様を追記。

## Validation / Result
- Fast成功。Full成功（171単体、Release build、署名、55helper検証）。初回はsandbox内で署名証明書参照に失敗、既存設定のまま許可範囲を広げ再実行し成功。
- test_verify.py：8件成功。git diff --check成功。
- モデル検証と32画面描画成功。Blue Cosmosの花火・Windows 98休憩を画像で目視確認。画像はbuild/pomodoro-compact-preview。
- 本番への配置・起動・終了は未実施。他の未コミット変更は保持。

## Remaining Issues
実画面での操作、アニメーションの体感、実際の音出し、OS視差効果設定を変えた確認は未実施。本番反映はユーザーの一括デプロイ時。

## 本番反映（利用者の追加依頼）
- /Applications/MyToolBox.appへ検証済みビルド一式を原子的に交換。既存と同じ署名要件、全ファイルのハッシュ・モード一致、全55helper・deep署名を確認。
- 本体79825を通常終了し、新本体12964を配置先から起動。起動中のsystemMonitor 41109、unitConverter 41357、windowManager 65602はPIDを維持。ポモドーロは反映前に未起動、次回起動から新版。
- 既存ビルドに含まれる一覧・カウントダウンの更新も配置。設定や編集中データは変更しない。
- 旧版の一時.appと固定ビルド出力.appは成功確認後に削除。証跡はbuild/validation/pomodoro-deploy。
- この配置検証はNSWorkspaceのPID／起動パス確認。AXウィンドウ一覧・内容は取得していない（JSONのwindowsは空の未取得欄）。演出・実音の実機確認は引き続き未実施。
