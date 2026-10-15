# 2026-10-15：メニューバー指標の調整

## Request
RAMを%、SSDを利用可能容量の整数GB、Batteryに充電中の雷マークを表示。

## Investigation
AGENTS/CURRENT/TESTING、CODEMAPとStatusStrip参照を確認。RAMの使用率、Storageの空き容量、IOPowerSources由来の充電中フラグは既存collectorに存在する。

## Changes
メニューのRAMを使用率へ、SSDを空き容量の10進GB（小数点以下切捨て）へ変更。SSDメニューだけ容量単位設定によらずGB固定。充電中が1の場合のみBATラベルへ雷マークを追加。AC接続だけでは点灯しない。取得不可・待機の表示は保持。

## Files Changed
Sources/MyToolBox/UI/StatusStrip.swift、OPERATIONS.md、docs/FEATURES.md、描画プレビュー、本sessionと索引。

## Validation
FastとFull（文書・Swift単体12件・Xcode Release build・codesign）を実施。オフスクリーン描画でRAM%とSSD整数GBを確認。実際の充電開始／終了によるマーク切替は未検証。取得処理の変更なし。

## Result
更新済み.appを生成し、今回起動したアプリを更新版へ再起動。

## Remaining Issues
充電状態遷移と実デスクトップでの表示確認。既存の移行残課題はCURRENTと移行チェックリストを参照。
