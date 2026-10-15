# Code Map

ローカルsemantic index / IDE symbol searchは未提供。CODEMAP→rgのexact検索→実ファイル→references/tests/configurationの順に調べる。ローカルGit管理済み。追跡ファイルにはgit grepも使える。

| Feature | Primary paths | Search keywords | Key entry points | Related tests |
| --- | --- | --- | --- | --- |
| ツール一覧 | Sources/MyToolBox/App/ToolCatalog.swift、Sources/MyToolBox/UI/ToolLauncher.swift | ToolID、openTool | AppDelegate.showTools | 描画・実機導線確認 |
| ローカル11ツール | Sources/MyToolBox/Tools、Sources/MonitorKit/Tools | ToolWindows、ToolPage、BusinessDays、CSVDocument、CSVModel、SpeakerModel、MicrophoneModel、TextTransformModel、ClipboardFormatterModel、SequentialText、ClipboardTable、TextCleaner | ToolWindows.show | TextToolsTests.swift、LocalToolsTests.swift、tools/RenderLocalTools.swift |
| 行・置換・リスト | Sources/MonitorKit/Tools/LineTools.swift、StringReplacer.swift、ListConverter.swift、Sources/MyToolBox/Tools/LineToolViews.swift、ReplacerView.swift | LineTools、ReplacerModel、ClipboardWorkspaceView、TextProcessor | ToolWindows.show | LineUtilityTests.swift、RegexBudgetProbe.swift |
| 起動・メニューバー | Sources/MyToolBox/App/MyToolBoxApp.swift | NSStatusItem、NSPopover、togglePopover | AppDelegate | Xcode build、実機手順 |
| UI取得ループ・sleep・login | Sources/MyToolBox/App/MonitorStore.swift | suspend、resume、setLogin | MonitorStore.start | 実機手順、reset単体 |
| 一覧カード・詳細・グラフ | Sources/MyToolBox/UI/Dashboard.swift | Chart、LineMark | Dashboard | History単体、実機手順 |
| 2段メニューバー描画 | Sources/MyToolBox/UI/StatusStrip.swift | draw、Cell、accessibilityPerformPress | StatusStrip.update | オフスクリーン描画、実機手順 |
| メニュー注意色 | Sources/MonitorKit/Core/MenuAlerts.swift | MenuSeverity、levels、load | MenuAlerts.levels | MenuAlertsTests.swift |
| 設定UI | Sources/MyToolBox/UI/SettingsPanel.swift | Toggle、Picker | SettingsPanel | Preferences単体 |
| 設定・単位 | Sources/MonitorKit/Core/Preferences.swift | UserDefaults、MetricFormat | Preferences.load/save | testPreferencesPersistenceAndValidation、testUnitFormatting |
| 状態・差分・履歴 | Sources/MonitorKit/Core/Models.swift | Availability、CounterRate、CPUTicks、InterfaceRates、History | sample、append | Tests/MonitorKitTests/MonitorKitTests.swift |
| 定期ログ | Sources/MonitorKit/Core/MonitoringLog.swift | LogPreferences、append、prune | MonitoringLog.append | MonitoringLogTests.swift |
| 直列取得 | Sources/MonitorKit/Core/MonitorEngine.swift | actor、lastSlow、reset | MonitorEngine.sample | CLI PoC、実機手順 |
| CPU | Sources/MonitorKit/Monitoring/CPU.swift | host_processor_info、Pコア | CPUMonitor.read | CPUTicks単体、load-cpu証拠 |
| GPU | Sources/MonitorKit/Monitoring/GPU.swift | IOAccelerator、Device Utilization | GPUMonitor.read | PoC、GPU負荷試験 |
| RAM | Sources/MonitorKit/Monitoring/Memory.swift | host_statistics64、pressure、swapusage | MemoryMonitor.read | PoC |
| Network | Sources/MonitorKit/Monitoring/Network.swift | NET_RT_IFLIST2、PrimaryInterface | NetworkMonitor.read | InterfaceRates、loopback試験 |
| Storage | Sources/MonitorKit/Monitoring/Storage.swift | volume、IOBlockStorageDriver | StorageMonitor.read | CounterRate、PoC |
| Battery | Sources/MonitorKit/Monitoring/Battery.swift | IOPowerSources、AppleSmartBattery | BatteryMonitor.read | PoC、取得不可単体 |
| 温度・ファン | Sources/MonitorKit/Monitoring/Sensors.swift、Sources/MonitorKit/Utilities/SMCReader.swift | AppleSMC、SMCCodec、Tp09、FNum | SensorsMonitor.read、SMCReader.read | Tests/MonitorKitTests/SMCTests.swift、evidence/sensors-native.jsonl |
| OS補助・トポロジー | Sources/MonitorKit/Utilities/SystemAccess.swift | sysValue、logical-cpu-id、cluster-type | topology、entries、property | PoC |
| CLI PoC | Sources/Probe/main.swift | monitor-probe、JSONEncoder | Probe.main | evidence/*.jsonl |
| アプリアイコン | Resources/AppIcon/source.png、Resources/MyToolBox.icns、scripts/build_icon.py | CFBundleIconFile、iconutil | build_icon.py | ICNS変換、bundle確認 |
| プロジェクト生成 | scripts/generate_project.py | PBXNativeTarget、SWIFT_VERSION | main | Xcode build |
| 標準検証 | scripts/verify.py、scripts/app_verify.py | check、verify | main、verify | scripts/test_verify.py |
| 機能・測定定義 | docs/ | 指標、推定、移行 | TECHNICAL_VALIDATION.md | docsリンク検証 |

## References / Configuration / Data Dependencies
`MonitorStore → MonitorEngine → 各Monitor → SystemAccess/OS`。CLIもMonitorEngineを使う。UIの型はXcodeで共有ソースを直接compile、テストとCLIはPackage.swift経由でMonitorKitをimport。ビルド設定はgenerate_project.pyと生成済みpbxproj、privacy manifestはResources。監視のデータ依存はOSカウンター・IORegistry・Data volume・UserDefaults。新ツールは同梱JapaneseHolidays.json、ユーザー選択CSV、明示許可された音声入力を利用。Resources/Info.plistとMyToolBox.entitlementsにマイク用途/権限を定義。

```sh
rg -n 'CounterRate|InterfaceRates|reset' Sources Tests
rg -n 'MonitorEngine|sample\(' Sources Tests
rg --files -g AGENTS.md -g '*.swift' -g '*.py'
```

比較：`Sources/MonitorKit/Tools/Comparison.swift`（TextComparison/ListComparison）→ `Sources/MyToolBox/Tools/ComparisonView.swift`（ComparisonModel/ComparisonWorker）→ ToolWindows。`Tests/MonitorKitTests/ComparisonTests.swift`、`tools/RenderLocalTools.swift`。
