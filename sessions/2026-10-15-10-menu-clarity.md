# 仕切り削除・温度ラベル・RAM残り

## Request / Investigation
仕切り不要、CPU温度を分かりやすく、RAM残り容量も表示。AGENTS/CURRENT、関連CODEMAP・TESTING、StatusStripとMemoryMonitor・設定・呼び出し元を確認。

## Changes / Files Changed
StatusStripの仕切り線を削除。温度ラベルをCPU温度／GPU温度へ変更し使用率と区別。RAM使用率の横にRAM残り（小数2桁の10進GB）を追加。RAMの順序・非表示に連動。
MemoryMonitorに総量−推定使用量の利用可能容量を追加。freeと区別し、欠損・不整合は取得不可。単体テスト、現在地・機能・操作・測定定義・検証文書を更新。

## Validation / Result
Fast/Full成功（22テスト・Xcode Release・署名・.app）。実値PoCのRAM残り7.08/7.31GBで総量−使用量と一致（evidence/ram-available.jsonl）。オフスクリーン描画で仕切りなし・温度ラベル・RAM残りを確認。

## Remaining Issues
RAM残りは推定でありParallelsとの完全一致は保証しない。実デスクトップでの配置・ノッチとの干渉は未検証。
