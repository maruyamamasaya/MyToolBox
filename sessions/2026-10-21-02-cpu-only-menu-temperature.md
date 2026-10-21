# メニューバーの温度をCPUだけにする

## Request
メニューバーのGPU温度を非表示にし、CPU温度と詳細画面のGPU温度を維持する。

## Investigation
StatusStripのsensorsセル生成と参照、DashboardのGPU温度表示、MonitorEngine・Preferences・関連描画プローブを確認。子AGENTSなし。既存の他作業の変更は保持。

## Changes / Files Changed
- StatusStrip.swift：GPU温度セルを削除。CPU温度と注意色、GPU使用率、温度取得・詳細表示は維持。ツールチップも修正。
- RenderStatusStrip.swift：注意色の案内を更新。隔離UserDefaults・自動監視なしで起動し、通常描画はprohibitedにして本番設定／ログを保護。
- TESTING.md：描画コマンドの実依存を補完。CURRENT.mdに本番未反映の状態を追記。
- evidence/status-strip-preview.png、alert-colors-fixture.png：実Viewの非表示描画を更新。

## Validation
- Fast成功。
- Full初回はsandbox内で署名証明書参照不可。制限外で再実行して成功（174単体・Release build・署名検証）。
- scripts/test_verify.py：8件成功。
- 描画プローブをコンパイルし、通常／合成注意色の2画像を目視確認。温度欄はCPUのみ、合成85.0°Cの黄色表示を確認。sandbox内の実センサー欠測は「—」のまま表示。

## Result / Remaining Issues
開発版の変更完了。本番への配置・起動・実メニューバーの確認は未実施。GPU温度は既存の詳細画面実装を維持。
