# 2026-10-15：温度の小数・単位表示

## Request
CPU/GPU温度を小数1桁と値の横の°Cで表示する。

## Investigation
AGENTS/CURRENT、StatusStripのsensorNumberと呼出し、既存単位設定、描画ツール、TESTINGのFast/Fullを確認。

## Changes
メニュー温度を52.3°C形式へ変更。華氏設定では°Fに追従。上段ラベルはCPU/GPU、ファンは整数を維持。

## Files Changed
StatusStrip.swift、docs/SENSORS.md、OPERATIONS.md、描画プレビュー、本sessionと索引。

## Validation
Fast/Full（既存単体17件・Xcode Release・署名）、実測サンプルによるオフスクリーン描画を確認。

## Result
更新版.appを生成・再起動。

## Remaining Issues
実デスクトップの目視確認と既存のセンサー精度・長時間検証は別途。
