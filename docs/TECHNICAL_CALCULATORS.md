# 容量・進数・インフラ計算

一覧から5つの独立windowを開く。通信・ファイル保存なし、共通3テーマに対応。結果は行単位／全体コピー可能。入力不正時は結果を隠して理由を表示する。

- 容量単位変換：数値＋単位の自動読取／単位選択。B、KB〜TB（1000倍）、KiB〜TiB（1024倍）。小数はDoubleの近似値。数値は3桁ごとのカンマ入力に対応。
- 進数変換：入力基数2〜60、出力2・10・12・16・24・60と任意基数。符号付き整数、0b／0x、10進カンマ対応。1024桁上限、長除算で整数精度を維持。数字は0–9・A–Z・a–x、37進以上は大小区別。
- 帯域・転送時間計算：容量と時間からMbps／Gbps／MB/s、容量と帯域から秒・日時。容量は10進、byte=8bits、オーバーヘッドなしの理論値。
- RAID計算：0／1／5／6／10、最大1000台、GB／TB。総量・使用可能量・効率・耐障害性。RAID 1は全台ミラー、10は4台以上かつ偶数、同一ペア2台故障不可。混在容量は最小容量を入力、管理領域を除く理論値。
- SLA計算：0〜100%、99／99.9／99.99／99.999のプリセット。日・週・30日月・365日年、秒に丸め1秒未満は小数。

参照元はユーザー指定の公開Web版：
[容量](https://maruyamamasaya.github.io/tool/byte-converter/)・[進数](https://maruyamamasaya.github.io/tool/number-base-converter/)・[帯域](https://maruyamamasaya.github.io/tool/bandwidth-calculator/)・[RAID](https://maruyamamasaya.github.io/tool/raid-calculator/)・[SLA](https://maruyamamasaya.github.io/tool/sla-calculator/)。ネイティブUIとして再実装し、入力元基数の選択から変換する形式に統一。

検証：TechnicalCalculatorsTestsが容量倍率、不正値・範囲超過、64bit超の整数往復、大小区別、帯域の逆算、RAID各構成と制約、SLAの境界を確認する。RenderLocalToolsの`--calculators-only`で5画面を描画。実機の代表入力・個別／全体コピー・不正入力は確認済み。詳細は[実機記録](../sessions/2026-10-15-32-calculators-installed.md)。
