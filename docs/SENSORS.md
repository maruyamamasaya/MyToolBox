# M1 Maxの温度・ファン取得

2026-10-15追加。CPU/GPU温度とファン実回転数を通常ユーザー権限で読み取る。管理者権限、特権ヘルパー、ファン制御・書込操作なし。

## 測定定義

| 表示 | SMCキーと算出方法 | 単位 |
| --- | --- | --- |
| CPU温度 | 下記E2点＋P8点、全10点の算術平均 | °C（UIで°Fへ換算可能） |
| CPU Eコア温度 | Tp09 / Tp0T の2点平均 | °C |
| CPU Pコア温度 | Tp01 / Tp05 / Tp0D / Tp0H / Tp0L / Tp0P / Tp0X / Tp0b の8点平均 | °C |
| GPU温度 | Tg05 / Tg0D / Tg0L / Tg0T の4点平均 | °C |
| ファン数 | FNum（ui8） | 基 |
| ファン1・2回転数 | F0Ac / F1Ac（実機ではflt、fpe2もdecode対応） | rpm |
| ファン回転数（詳細の代表値） | 全ファンの最大値。メニューでは番号順に全基を表示 | rpm |

温度キーのCPU/P/E/GPU分類はStatsのM1世代対応表を参照。Apple公認・校正済みの位置情報ではなく、Machの論理コア番号に結び付けない。採用するチップは実証済みのApple M1 Maxに限定し、他機種の温度は取得不可とする。

SMCの各点はセンサー報告値、平均は計算値。絶対温度の校正、hotspot代表性、Parallelsとの同時刻の数値一致は未検証。ユーザーの比較画像はP約52℃、E約52℃、GPU約51℃、両ファン0 rpmで、こちらの観測と近いが測定窓が違うため精度検証とはしない。

## 方式と安全境界

- AppleSMCへIOServiceOpenし、IOConnectCallStructMethodのselector 2を使う非公開80-byte ABI。
- 要求commandは情報取得9と値読み取り5のenumのみ。書込command 6・mode変更・unlock・回転数目標の操作は実装しない。
- 応答サイズ、ファームウェアresult、型、データ長を確認。fltはlittle-endian Float32、sp78は符号付き8.8、fpe2はunsigned14.2。未知型・NaN/Infは取得不可。
- 温度は0超〜130℃の検証範囲外なら取得不可。欠損センサーを除外して平均をすり替えない。ファンは0〜20,000rpmを許容し、実際の停止値0を保持する。
- FNumの成功値0だけを非搭載とする。FNum取得失敗を0基と扱わない。個数は0〜8の整数を検証し、各基の読取失敗は独立表示する。
- MonitorEngineのactor上で5秒周期。各周期で接続を作成・closeするため復帰後に古い接続を保持しない。CPU/GPU詳細へ同じ温度サンプルを配信する。
- 温度はメニュー・詳細とも小数1桁。メニューでは値の直後に°C（華氏設定なら°F）を付ける。ファンは整数表示。メニューバーのFANはファン1/ファン2順のrpm。欠損は「—」。ノッチ／他の常駐アプリで収まらない場合はSensors非表示やcompactで調整する。

## 証拠と検証

- [限定キーPoC](../evidence/smc-poc.txt)：CPU10点・GPU4点のflt値、FNum=2、F0Ac=F1Ac=0を取得。
- [統合PoC 7サンプル](../evidence/sensors-native.jsonl)：10:33:39–45 JST。最初のCPU平均52.47℃（P52.41/E52.71）、GPU50.75℃、両ファン0rpm。6秒後CPU53.58℃/GPU50.96℃へ更新。
- CPU/GPU詳細へ同一値が反映されること、5秒周期の再取得時刻が進むことをJSONで確認。
- [SMCTests](../Tests/MonitorKitTests/SMCTests.swift)：ABI、型変換、符号、成功0rpm、欠損／異常値、厳格平均、旧設定移行。実ハードウェアを使わず異常系を検証。
- [描画プレビュー](../evidence/status-strip-preview.png)：実測値のオフスクリーン描画。実デスクトップの操作確認とは区別。
- 開発サンドボックス内ではSMC接続拒否（-536870174）。通常ユーザー実行では取得成功。権限拒否時も他カテゴリの監視を継続する。
- ファンの回転中の実測、温度上昇の負荷試験、睡眠復帰、長期安定性は今回未実施。回転確認のためにファンを強制駆動しない。

## 参考実装とライセンス

Stats、revision `c9e7ebe3390a84e3075946ffe39dda709c4747b1` の[SMCプロトコル](https://github.com/exelban/stats/blob/c9e7ebe3390a84e3075946ffe39dda709c4747b1/SMC/smc.swift)と[センサー対応表](https://github.com/exelban/stats/blob/c9e7ebe3390a84e3075946ffe39dda709c4747b1/Modules/Sensors/values.swift)を参照。MITライセンス確認済み。80-byteの明示的バイト列による読み取り専用実装とし、制御処理は移植しない。

帰属・利用条件は[THIRD_PARTY_NOTICES](../THIRD_PARTY_NOTICES.md)。MIT全文をソースと.app内のResources/Stats-LICENSE.txtへ同梱する。外部ライブラリの実行時依存は増やさない。
