# 2026-10-15：MB/sの通信速度を黄色で表示

## Request
GB/sへは切り替えず、MB/s表示の通信速度を明るい黄色にして通信中とわかりやすくする。

## Investigation
AGENTS/CURRENT、CODEMAP、StatusStripのCell/draw・networkMenu参照、既存テスト、TESTING、描画ツールを確認。

## Changes
受信／送信それぞれの表示がMB/sになった行だけ淡い明るい黄色に変更。KB/s・待機・取得不可は通常色。100MB/s超も既存通りMB/sを維持。描画ツールへ明示fixtureオプションを追加し、本番の監視値と分離。

## Files Changed
UI/StatusStrip.swift、tools/RenderStatusStrip.swift、OPERATIONS、描画プレビュー、本sessionと索引。

## Validation
Fast/Full、既存単体18件、Xcode Release・署名。受信だけMB/s／送信だけMB/sのオフスクリーンfixtureで色を確認。fixtureは実測・通信試験の証拠ではない。

## Result
更新版.appを生成・再起動。

## Remaining Issues
実際のメニューバー背景・OSテーマ別の視認性は未検証。
