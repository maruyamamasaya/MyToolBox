# 技術検証・測定定義

検証日：2026-10-15（日本時間）。Phase 1の取得可否を確認し、取得可能な範囲をMVP化した。全要求の完了・移行完了ではない。

## 環境・証拠

- macOS 26.6.2 / arm64、Xcode 26.6 (17F113)、Swift 6.3.3。
- 通常ユーザーの `sysctl`：Apple M1 Max、34,359,738,368 bytes、10論理コア、perflevel0=8 / perflevel1=2。
- IODeviceTreeの `logical-cpu-id` / `cluster-type`：この実機は0–1=E、2–9=P。コードには番号を固定しない。完全な対応がなければP/Eは取得不可。
- [通常ユーザーPoCの5サンプル](../evidence/poc-native.jsonl)：2026-10-15 10:06:51–55 JST。数値はその時点の観測で、校正や長期精度の証明ではない。
- [実行環境のサンドボックス内3サンプル](../evidence/poc-sandbox.jsonl)：ネットワークは取得不可を返し、他モジュールは動作継続。アプリ自身はApp Sandboxを使用しない。
- 開発環境の制限を外した実行も通常ユーザー権限。sudo、特権ヘルパー、設定変更、外部送信なし。
- 証拠JSONは監視値・IF名・Registry IDのみ。MAC/IP、SSID、機器シリアル、全IORegistryダンプは保存しない。

## 指標ごとの方式・限界

| 指標 | 定義・単位・取得方式 | 取得実績と制約 |
| --- | --- | --- |
| CPU全体・各コア | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` のuser+system+nice差分 / 全tick差分、% | 全体62.34%、P平均53.39%、E平均98.14%（最終サンプル）。全体は10コア等重み平均、最大100%。瞬間値ではなく前回からの平均 |
| P/E対応・コア数 | IODeviceTree、sysctl、Machの論理コア数 | P8/E2。IORegistryキーは非公開・機種依存。sysctlのperflevelは調査で照合、対応付け自体はlogical-cpu-idを使用。OS更新時に再検証 |
| CPU/GPU温度 | AppleSMC読み取り、CPU10点・GPU4点平均、°C | M1 Maxで取得成功。P8/E2別も表示。定義・証拠は[センサー検証](SENSORS.md) |
| GPU全体使用率 | IOAccelerator / PerformanceStatistics / Device Utilization % | 9%を観測。システム全体の機種依存ドライバー統計。内部平均期間は非公開。複数GPUの場合は集計未定義として取得不可 |
| GPU基本情報 | Metalの名称・hasUnifiedMemory | Apple M1 Max、統合メモリあり。Metalの自アプリ稼働時間を全体使用率に流用しない。GPUコア数は未対応 |
| RAM総量 | hw.memsize、bytes | 32 GiBを取得 |
| RAM使用量・使用率 | `(active+inactive+wired+compressor−external−purgeable) × pageSize`、bytes、総量比% | 26,786,889,728 bytes / 77.96%を観測。Activity Monitorに近い分類を狙う推定式。完全一致未検証。キャッシュ・purgeableの重なりやOS計上差がある |
| RAM利用可能容量（推定） | 総容量−上記の推定使用容量、bytes | メニューのRAM残り。即時未使用freeとは異なり、同じ推定式の限界を引き継ぐ。総量／使用量欠損・範囲外は取得不可。メニューは10進GB小数2桁 |
| RAM空き・キャッシュ・圧縮 | host_statistics64、free / external / compressorページ×pageSize | free=即時未使用。キャッシュ=file-backed、purgeableと重複し得るため合算しない。圧縮は圧縮後の物理量。free+used=totalとは限らない |
| Memory pressure | kern.memorystatus_vm_pressure_level | 1=正常を取得。2=警告、4=危険。それ以外・失敗は取得不可。使用率から推測しない。過去のpressure推移は未対応 |
| Swap | vm.swapusage | 使用4,055,695,360 bytes / 総量5,368,709,120 bytesを取得 |
| Network | NET_RT_IFLIST2 / if_data64 64-bit累積差分、bytes/s | en10の受信56,603 B/s、送信943 B/sを観測。IF up/runningは疎通保証ではない |
| Network集計 | autoはSystemConfigurationの主IPv4、なければIPv6 IF。手動指定可能 | 単一IFのみ。VPN・bridge・物理を重ねて足さない。VPN利用時autoが希望の経路とは限らない。Wi-Fi/Ethernet等を別集計する用途はIFを指定 |
| Network累積期間 | OSのIF生成／リセット以降、bytes | 起算時刻はAPIから不明。起動時リセットでもアプリ開始以降でもない。IF名＋index変更・消失・down・カウンター減少で差分基準を更新。履歴の通信量総計は未対応 |
| APFS容量 | Data volumeのvolumeTotalCapacity/volumeAvailableCapacity、bytes。使用=総−空 | 総994,662,584,320 / 空182,235,394,048 bytes。APFS共有領域を含む値で、Data単独のファイル占有量ではない。各volumeを合算しない。purgeableの将来回収可能量を空きへ加算しない |
| Disk I/O | IOBlockStorageDriver StatisticsのBytes (Read/Write)差分、B/s | 6ドライバー、読込20.83 MB/s / 書込13.90 MB/s。Registry IDで一意化しAPFS子統計は加算しない。物理・仮想ドライバーを含む論理I/O、内部SSDの物理転送量とは異なる。イメージと背後ディスクで同一データが複数層を通る場合がある |
| Battery残量・電源・充電 | IOPowerSources、%・状態 | 79%、AC接続、非充電を取得。OS健康状態はCheck Batteryを取得（画面に原文表示） |
| Batteryサイクル・最大容量 | AppleSmartBatteryのCycleCount/AppleRawMaxCapacity/DesignCapacity | 270回、最大6870 / 設計8694 mAh、容量維持率79.02%。機種依存・非公開単位のため容量は推定。正規化されたMaxCapacity=100をmAh扱いしない |
| Battery残り時間 | IOPSGetTimeRemainingEstimate、秒を分へ変換 | OS推定。今回AC使用のため取得不可（理由表示）。放電時の値は未検証 |
| Battery温度・電力 | Temperature / Amperage等は存在を調査 | 単位・符号・校正・電源経路未検証。現在は取得不可。数値換算を実測と見なさない |
| Fan | SMC FNum / F*Ac、rpm | 2基の停止値0を取得成功。回転中未検証。制御／書込なし。[センサー検証](SENSORS.md) |

すべて取得は通常ユーザーの読み取り専用API。公開APIでも実行環境に制限される場合がある。非公開情報は将来消失する可能性があるため、欠損時に取得不可へ戻す。

## 差分・履歴・実行モデル

- CPUはtick差分、I/Oは実測の単調時刻差分を使う。設定した1秒で割り切らない。初回、カウンター減少、非正の経過、30秒超の中断は計測待ち。
- CPU tickの32-bit wrapは推測補正せず1サンプル待つ。I/Oは64-bitカウンター。
- 履歴はタイムスタンプと単調時刻を持ち、最新から60秒を保持。1/2/5秒変更で点数が変わる。欠測は0補完せず線を分断。時計変更時も保持期間は単調時刻で決める。
- サンプルはMainActor外のactorで直列実行。UIループが完了後に待機するため重複しない。実際の周期は設定間隔＋取得所要時間。
- Battery/Sensorsは5秒以上間隔で再取得。他は毎サンプル。slow値の時刻は画面注記あり（最大5秒程度前）。
- sleep通知でループをキャンセルしUI値を待ちへ戻す。wake後は差分基準をクリア。通知到着時に実行中の同期API呼出しは中断せず、結果を破棄する。
- 各モジュールの読取失敗は値状態として返す。ただしOS API自体のハングを強制中断するtimeoutは未実装。

## 代替案と未検証

温度・ファンは追加のSMC読取検証で取得成功。Stats（MIT）のプロトコルと対応表を参照し、ライセンスを同梱。詳細は[センサー検証](SENSORS.md)。powermetrics、ファン制御・書込は未実行。絶対温度の校正と回転中・睡眠復帰の確認は残る。

UI操作確認はComputer Use接続が2回timeoutしたため未実施。起動・プロセス常駐は確認したが、メニューバー視認・グラフ描画・クリック・操作による設定保存は未検証。詳細手順は[実機検証と移行](MIGRATION_CHECKLIST.md)。

## 一次資料

- [Apple XNU host_info.h](https://github.com/apple/darwin-xnu/blob/main/osfmk/mach/host_info.h)：CPU tick定義。実装時はインストール済みSDKのprocessor_info.h、vm_statistics.h、sysctl.hも確認。
- [Apple volumeAvailableCapacityKey](https://developer.apple.com/documentation/foundation/urlresourcekey/volumeavailablecapacitykey)：容量APIの定義。
- [Apple SMAppService.register](https://developer.apple.com/documentation/servicemanagement/smappservice/register())：明示操作時のログイン起動登録。
- [Apple Required Reason API](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)：UserDefaults・容量表示・経過時間測定のprivacy manifest。配布審査済みを意味しない。

## 短時間負荷試験

- [CPU 13サンプル](../evidence/load-cpu.jsonl)：4worker×5秒。負荷前約30.5–31.7%、負荷区間50.5–81.6%、回復30.6–38.2%。追従を確認。他プロセスの負荷が混在するため精度校正ではない。
- [GPU 13サンプル](../evidence/load-gpu.jsonl)：別プロセスのMetal computeを5秒。負荷前0–8%、負荷中87–90%、回復0%。全体統計の追従を確認。診断ツールはアプリに組み込まない。
- [loopback 13サンプル](../evidence/load-loopback.jsonl)：127.0.0.1へ5,242,880 bytesを4秒程度で転送。受信約1.17–1.22 MB/sへ増加後低下。送信も同区間で更新。ヘッダー等があるためpayloadとOS byteカウンターは一致しない。外部通信なし。
- GUIの旧ビルドのプロセス一点観測：起動2分53秒、CPU 0.5%、RSS 112,464 KiB（約109.8 MiB）。8時間安定性や新2段UIの負荷の証明ではない。

[2段表示プレビュー](../evidence/status-strip-preview.png)は実機のサンプルを使ったオフスクリーン描画。デスクトップのスクリーンショットではなく、画面操作・ノッチとの干渉・OSテーマごとの視認性は未検証。
