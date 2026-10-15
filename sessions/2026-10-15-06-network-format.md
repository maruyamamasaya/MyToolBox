# 2026-10-15：メニュー通信速度の単位・桁数

## Request
KBを最小単位とし、10以上は整数、100以上は0.1MB/s形式へ切り替える。

## Investigation
AGENTS/CURRENT、CODEMAP、MetricFormatとStatusStrip参照、単位テスト、TESTING、表示設定を確認。

## Changes
メニューの通信表示を10進KB/s以上に統一。10KB/s未満は小数1桁、10〜99は整数、100以上は小数1桁MB/s。丸めで10/100に達する場合も桁数・単位を切替。詳細は従来の単位設定に従い、設定UIへ例外を明記。待機／取得不可は維持。

## Files Changed
Core/Preferences.swift、UI/StatusStrip.swift・SettingsPanel.swift、MonitorKitTests、OPERATIONS、TESTING、描画プレビュー、本sessionと索引。

## Validation
Fast/Full、単体計18件（境界値・小さい速度・0・欠損を含む）、Xcode Release、署名、オフスクリーン描画。

## Result
更新版.appを再起動し反映。

## Remaining Issues
実デスクトップの目視と、既存の長時間・実IF切替検証は別途。
