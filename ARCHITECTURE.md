# Architecture

## System Overview
MyToolBoxはツール集のシェルと個別ツールで構成する。システムモニターと11のローカルツールを実装。Swiftの共通監視ライブラリをCLI PoCとネイティブアプリが共有する。外部通信・DB・認証不要。

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
Swift 5 language mode（Xcode 26.6 / Swift 6.3.3で検証）、macOS 14+ arm64。SwiftUI、AppKit、AVFoundation、CoreAudio、AudioToolbox、Charts、Metal（基本情報のみ）、IOKit、ServiceManagement、SystemConfiguration。SQLite3はmacOS同梱ライブラリを使用。第三者依存なし。Python 3標準ライブラリは検証とXcodeプロジェクト生成のみ。

## Directory Structure / Main Components
- `Sources/MyToolBox/App/ToolCatalog.swift`：実装済みツールのID・名称・説明・アイコン。AppDelegateが明示的に画面へ振り分ける。
- `Sources/MyToolBox/App`：アプリ起動・ステータス項目・transient popover・UI状態・ログイン起動・sleep通知。
- `Sources/MyToolBox/UI/AppTheme.swift`：3テーマのパレットと背景。ThemeRootが共通AppStorageを監視しEnvironmentへ注入。入力モデルを再作成せず全windowへ反映。ThemeControls/ThemeWindowChrome/ThemeNativeTable/ThemePixelIconがWindows 98部品を描画。詳細は[テーマ](docs/THEMES.md)。
- `Sources/MyToolBox/UI`：390×620ptの一覧カード・詳細・グラフ・設定。popover内で画面を切替、再表示時は一覧へ戻す。
- `Sources/MyToolBox/Tools`：共通ToolPage/ToolCard、11専用UI、ToolWindows、CSVModel、SpeakerModel、MicrophoneModel。window終了/sleepで音声停止。
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
監視はローカルOS APIのみ。特権ヘルパー、sudo、SMC書込なし。Git一括管理は明示操作時にリモート通信する。App Sandboxは使わず、通常ユーザーの読取権限で実行。非公開キーの欠損・OS制限は値の取得不可として扱う。APIハングの強制timeoutは未実装。

## Deployment
[MyToolBox.xcodeproj](MyToolBox.xcodeproj)は実在するnative app target。共有Swiftファイルを直接コンパイルする。Swift Packageはライブラリ・CLI・単体テスト用で、Xcodeの外部package解決を不要にした。ローカル.appは証明書選択用xcconfigで署名を固定可能（fresh checkoutの既定はad hoc）。このMacの通常更新は既存Apple Development証明書を使用。CI/CD・公証なし。[署名運用](docs/CODE_SIGNING.md)。

採用理由は[0002](decisions/0002-poc-and-native-mvp.md)。

比較ツールはテキスト差分とリスト比較の入力を共有する。ComparisonModelはUI状態、専用ComparisonWorker actorはUIスレッド外の直列計算、MonitorKitのTextComparison/ListComparisonは純粋ロジック。編集時は旧Taskをcancelし、古い結果を公開しない。LCSと変更行対応付けは行数・バイト数・協調的な時間予算で制限する。詳細は[比較ツール](docs/COMPARISON_TOOLS.md)。


カレンダーはCalendarWorkspaceModelが候補日・営業日範囲・独自休日をwindow内で保持し、日程候補／営業日計算の2画面が共有する。ScheduleCandidatesは選択・時間検証・整形の純粋ロジック、ToolCalendarは単一／複数選択の共通描画。ToolID.businessDaysを維持し表示名だけカレンダーへ変更。詳細は[カレンダー](docs/CALENDAR.md)。

User-Agent Viewerは非永続WKWebViewへ同梱HTML文字列だけを読み込み、navigator/screenを評価してネイティブ画面へ表示する。リモートURLへ遷移しない。UA解析はMonitorKitのUserAgentInfoで共有。取得値はメモリ内のみ。

画像リサイズはImageIO/CoreGraphicsを使用し、専用ImageResizeWorker actorで読込・デコード・変換・保存を直列処理する。プレビューと出力はwindow内メモリで保持。寸法・形式・品質変更で古い結果を破棄し、保存は明示操作。追加ランタイム・外部パッケージ不要。

時間ツールはUtilityTimerの日時差分をTimerBoardModel／FocusTimerModelが0.25秒ごとに表示へ反映する。ボードは設定・実行基準日時をローカル保存し、close時に一時停止。TimeCalculationは勤務時間・時間帯合計の純粋計算。詳細は[時間ツール](docs/TIME_TOOLS.md)。

サーバー・ネットワーク・日常計算11本は純粋ロジックをMonitorKit、専用画面をMyToolBox/Toolsへ分離。ネットワーク・サーバーカテゴリを追加。コマンド実行・通信は行わず、ツリー構成・開閉状態と辞典のお気に入り/履歴をUserDefaultsへ保存、ツリーは明示JSON保存。詳細は[仕様](docs/SERVER_AND_EVERYDAY_TOOLS.md)。

SQLツールは字句ベースの整形・基本SELECT説明と、SQLPlaygroundWorker actorが所有するメモリ内SQLiteを共有入力の3タブに統合。SQLの外部DB・ファイル操作はauthorizerで拒否し、時間・出力・DB容量を制限する。詳細は[仕様](docs/SQL_TOOLS.md)。

マイカレンダーは既存の予定調整から独立。PersonalCountdownが日付／時間目標と日本時間の日数計算、PersonalCountdownStoreがUserDefaults保存、PersonalCalendarModelが編集確定と読込エラー保護を担当。月表示はToolCalendarと同梱祝日を再利用。[仕様](docs/PERSONAL_CALENDAR.md)。

セキュリティ状態は通常の秒周期sampleから独立したSecurityCollector actorで起動／手動時のみ取得。MonitorStoreが実行中を管理し重複を防止、SecurityDetailが表示。3つの固定読取コマンドは各5秒でtimeout。詳細は[取得仕様](docs/SECURITY.md)。

ウィンドウマネージャーはWindowLayoutの純粋座標計算と、WindowManagerModelのAccessibility操作／Carbonホットキーを分離。ToolWindows初期化時から外部アプリの選択を追跡し、復元位置はメモリのみ。明示操作時にだけ外部ウィンドウを変更。[仕様](docs/WINDOW_MANAGER.md)。

Git一括管理はGitBatchWorker actorが通常ユーザーのGitを引数配列で直列実行する。明示操作でoriginへfetch／pushを行う。画面はローカル読込と通信を区別し、更新／コミット送信は確認付き。[仕様](docs/GIT_BATCH.md)。
