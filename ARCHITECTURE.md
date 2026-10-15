# Architecture

## System Overview
MyToolBoxはツール集のシェルと個別ツールで構成する。システムモニターと10のローカルツールを実装。Swiftの共通監視ライブラリをCLI PoCとネイティブアプリが共有する。外部通信・DB・認証不要。

```text
AppDelegate → ツール一覧NSStatusItem / 数値NSStatusItem → 単一NSPopover
                          ToolLauncher → Dashboard / SettingsPanel
                         ↕ MonitorStore (MainActor, 表示・設定・通知)
                         ↓ await
                     MonitorEngine (actor, 直列取得・別周期)
             CPU / GPU / Memory / Network / Storage / Battery / Sensors
                         ↓
       Mach / sysctl / IORegistry / SystemConfiguration / IOPowerSources
```

## Technology Stack / Important Dependencies
Swift 5 language mode（Xcode 26.6 / Swift 6.3.3で検証）、macOS 14+ arm64。SwiftUI、AppKit、AVFoundation、CoreAudio、AudioToolbox、Charts、Metal（基本情報のみ）、IOKit、ServiceManagement、SystemConfiguration。第三者依存なし。Python 3標準ライブラリは検証とXcodeプロジェクト生成のみ。

## Directory Structure / Main Components
- `Sources/MyToolBox/App/ToolCatalog.swift`：実装済みツールのID・名称・説明・アイコン。AppDelegateが明示的に画面へ振り分ける。
- `Sources/MyToolBox/App`：アプリ起動・ステータス項目・transient popover・UI状態・ログイン起動・sleep通知。
- `Sources/MyToolBox/UI`：390×620ptの一覧カード・詳細・グラフ・設定。popover内で画面を切替、再表示時は一覧へ戻す。
- `Sources/MyToolBox/Tools`：共通ToolPage/ToolCard、10専用UI、ToolWindows、CSVModel、SpeakerModel、MicrophoneModel。window終了/sleepで音声停止。
- `Sources/MonitorKit/Tools`：CSVパーサ・書出し、営業日、音声信号の純粋ロジック。祝日JSONをbundleから読込。テキスト変換も共通処理として実装。
- `Sources/MonitorKit/Core`：値状態、差分、履歴、設定、取得actor、独立したログ保存actor。
- `Sources/MonitorKit/Monitoring`：独立した機能別collector。
- `Sources/MonitorKit/Utilities`：限定IORegistryプロパティ、sysctl、トポロジー、読み取り専用SMCバイトプロトコル。
- `Sources/Probe`：同一collectorを実行するJSONL CLI。
- `Tests/MonitorKitTests`：純粋ロジック・UserDefaultsのテスト。
- `tools` / `scripts/load_probe.py`：任意実行の短時間負荷試験。アプリには含まない。

ツール一覧と数値メニューは同じMonitorStoreを参照し、監視タスクを複製しない。追加ツールはCatalogへ登録し専用UI・処理を実装する。プラグインロードや未実装ツールのダミー起動は行わない。新10ツールはToolWindowsが独立NSWindowを管理し重複起動しない。CSVの未保存close/終了は確認、音声処理は明示操作で開始。録音tapはロックで保護した最大10秒のメモリだけを触り、UIは0.1秒周期で読み出す。

テキスト系ツールは専用TextProcessor actorで直列変換し、入力待ち・キャンセル・結果確認をMainActorが管理する。CSVの表示表CSVGridはクリップボード整形と共有。表の選択だけでセル編集のフォーカスを解除しない。行ツールは3操作で入力を共有、ClipboardWorkspaceViewは表/リストの独立状態を保持する。検索置換はICU進捗で中断と入力/結果/一致数上限を設ける。

## Data Flow
MainActorの1つのTaskがactor取得完了を待ち、snapshot・時刻付き60秒historyを更新後に1/2/5秒待つ。取得はactor上の同期処理で重複なし。Battery/Sensorsを5秒周期でキャッシュ。SensorsはM1 Max温度とFNum/F*Acを読取り、CPU/GPU詳細へ同じ温度を反映。sleepでTaskをcancelし、wakeでactorの差分をresetして再開。キャンセル中の結果はUIへ反映しない。

値はavailable / waiting / unavailable / notPresentで表現し、欠損はnilと理由を持つ。失敗を0で埋めず他カテゴリを継続。UserDefaultsへ表示・ログ設定を保存する。任意の定期ログはMonitoringLog actorが主要指標を日別JSONLへ保存・期限整理する。差分・保持期間は単調時刻、ラベルは実時刻。詳細は[測定定義](docs/TECHNICAL_VALIDATION.md)。

## API Structure / Database / Authentication / External Services
ローカルOS APIのみ。特権ヘルパー、sudo、SMC書込、ネットワーク送信なし。App Sandboxは使わず、通常ユーザーの読取権限で実行。非公開キーの欠損・OS制限は値の取得不可として扱う。APIハングの強制timeoutは未実装。

## Deployment
[MyToolBox.xcodeproj](MyToolBox.xcodeproj)は実在するnative app target。共有Swiftファイルを直接コンパイルする。Swift Packageはライブラリ・CLI・単体テスト用で、Xcodeの外部package解決を不要にした。ad hoc署名のローカル.app、CI/CD・公証なし。

採用理由は[0002](decisions/0002-poc-and-native-mvp.md)。
