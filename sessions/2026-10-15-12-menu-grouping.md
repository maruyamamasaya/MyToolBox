# FAN右側への1段表示集約

## Request / Investigation
GPU温度もアイコン付き1段表示、メモリ残りと温度をFAN右へ集約。AGENTS/CURRENT、CODEMAP/TESTING、StatusStripと設定・表示依存を確認。

## Changes / Files Changed
StatusStripで通常の2段項目の後ろにFAN→RAM残り→CPU温度→GPU温度を配置。CPU/GPUを1段の短い表記で区別。RAM/Sensors非表示を引き継ぎ、隠した項目を復活させない。注意色と明滅を維持。OPERATIONS/CURRENT/FEATURESを更新。

## Validation / Result
Fast/Full成功（22テスト、Xcodeビルド、署名・.app）。オフスクリーン描画で513×22ptの並び・アイコン・CPU/GPU表記を確認。

## Remaining Issues
右側グループの順序は固定。実デスクトップのノッチ干渉は未確認。
