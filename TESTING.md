# Testing

## Test Strategy

開発時は[開発時の注意点](docs/DEVELOPMENT_WORKFLOW.md)に従い、単体・隔離モデル・オフスクリーン描画を優先する。以下の実機手順は必要時の確認項目であり、開発の都度実行する指示ではない。未実施は明記し、本番反映はユーザーの一括デプロイに委ねる。
文書・Swiftロジック・ネイティブXcodeビルドを標準verifyで検証する。手動UI・実機試験・比較は別管理で、自動verify成功と混同しない。外部依存パッケージ・外部通信なし。

## Fast Validation

```sh
python3 scripts/verify.py --fast
```

必須文書・構造・リンクとSwift単体テストを実行。設定変更・OS実機操作を行わない。

## Full Validation / 標準Verify

独立ツールの専用アイコン：Fullで全55helperのCFBundleIconFile・素材一致を確認。検証器の負例で欠落・誤画像を拒否。素材一覧のオフスクリーン描画とDock実機確認の区別は[アイコン仕様](docs/TOOL_ICONS.md)を参照。

一覧レイアウト変更時はtools/VerifyLauncherLayout.swiftで実際の可変ToolLauncherを4テーマ×3サイズで非表示描画し、fittingSize計測も確認する。SwiftUIの未指定／無限大の計測提案を有限幅へ正規化する必要がある。コンパイル対象はMonitorKit/CoreのVisualTheme・ToolFavorites、ToolCatalog、UIのAppTheme・Theme*.swift・ToolLauncherとプローブ。実機の起動と上下スクロールも確認する。

```sh
python3 scripts/verify.py
python3 scripts/test_verify.py
```

Fastに加え文書行数制約、Xcode Release build、.app実在、codesign検証を実行。ログは `build/validation/`。文書verifyだけでアプリ検証を省略する経路は標準コマンドに設けない。検証器の負例はtest_verify.pyで隔離コピーに対して試す。

単独コマンド：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache" swift test --disable-sandbox --scratch-path .build
xcodebuild -project MyToolBox.xcodeproj -scheme MyToolBox -configuration Release -derivedDataPath build build
codesign --verify --strict build/Build/Products/Release/MyToolBox.app
```

SwiftPMの`--disable-sandbox`はmanifest/build sandboxの入れ子制限回避用。アプリの権限を昇格しない。SwiftPMのユーザーcache警告は環境依存。XcodeのCoreSimulator/AppIntents警告はこのmacOSアプリと別で、成功判定はコマンド終了コード・生成物・署名確認に基づく。

## 変更と必要な検証

| Change Type | Required Validation |
| --- | --- |
| 文言・リンク | Fast → Full、技術的事実との照合 |
| Core・取得ロジック | 関連単体テスト、Fast → Full、変更指標のPoC |
| UI | Fast → Full、実機表示／操作。不可なら未検証と明記 |
| 設定・sleep・IF | 差分／保存テスト、Full、実機チェックリスト |
| Xcode構成・ファイル追加 | generate_project.py再実行、Full |
| verify変更 | Python構文、test_verify.py、Fast → Full |

## 自動テスト対象

[MonitorKitTests](Tests/MonitorKitTests/MonitorKitTests.swift)：実経過差分、0の実測、カウンター減少、同時刻／逆行／長時間中断、CPU idle/busy/wrap、IF名／index変更、取得不能のJSON往復、設定の永続化／破損／補正、単位、60秒履歴と時刻逆行。OSをモックして実機成功と呼ぶテストはない。

## PoCと任意の負荷試験

```sh
.build/debug/monitor-probe 5 > evidence/poc-rerun.jsonl
# 引数: サンプル数（2–600）、省略可のIF（既定auto）
.build/debug/monitor-probe 5 en0
python3 scripts/load_probe.py cpu
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" xcrun swiftc tools/GPULoad.swift -o build/gpu-load
python3 scripts/load_probe.py gpu
python3 scripts/load_probe.py loopback
```

負荷試験は標準verifyへ含めない。CPU=4worker×5秒、GPU=ローカルMetal×5秒、loopback=127.0.0.1内の約5MiB転送。13サンプルの前・中・後を保存する。PC全体の他の負荷が混在するので校正試験ではない。CPU/GPUは同時実行しない。

サンドボックスのSystemConfiguration制限でauto IFが取れない場合は通常のTerminalで実行する。取得失敗時のJSONは失敗証拠として保存し、成功ログへ上書きしない。

## 実機・UI検証

手順・合否基準・未実施一覧は[移行チェックリスト](docs/MIGRATION_CHECKLIST.md)。値の定義は[技術検証](docs/TECHNICAL_VALIDATION.md)。Computer Useは2回timeoutし、GUI操作確認は未検証。2段メニューバーのオフスクリーン描画検証は実デスクトップの目視とは区別する。

オフスクリーンの2段表示確認（ユーザー設定を変更せず実サンプルで描画）：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" xcrun swiftc -parse-as-library Sources/MonitorKit/Core/*.swift Sources/MonitorKit/Monitoring/*.swift Sources/MonitorKit/Utilities/*.swift Sources/MyToolBox/App/MonitorStore.swift Sources/MyToolBox/UI/StatusStrip.swift tools/RenderStatusStrip.swift -o build/render-status
build/render-status
```

[evidence/status-strip-preview.png](evidence/status-strip-preview.png)はこの描画結果。実際のメニューバーのスクリーンショットではない。

## SMCセンサー検証

[SMCTests](Tests/MonitorKitTests/SMCTests.swift)を含むセンサーテスト。ABI位置・read-only command・型変換・不正サイズ／result／NaN・成功0rpm・欠損平均・設定移行を検証する。SMC実機読み取りは通常ユーザーで行い、sandboxによる拒否を権限昇格が必要なセンサーと混同しない。

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" xcrun swiftc -parse-as-library Sources/MonitorKit/Utilities/SMCReader.swift tools/SMCProbe.swift -o build/smc-probe
build/smc-probe
.build/debug/monitor-probe 7
```

回転中のファンと負荷追従は未検証。ユーザーの通常作業で回転した際、FAN表示とSensors詳細が同じrpm（丸め差のみ）になることを確認する。0rpmを偽装せず、取得失敗時は「—」。ファンの制御操作によるテストは行わない。[証拠と測定定義](docs/SENSORS.md)。

注意色は `MenuAlertsTests.swift` でBAT境界・外部電源・充電・不明状態、CPU継続／復帰／中断、RAMプレッシャー、SSD空き、温度境界を検証。`build/render-status --alert-preview` は合成値の色確認用。実測証拠ではない。実機ではBATの50%／20%と外部電源接続、赤が1秒ごとに読める濃淡で変わること、「視差効果を減らす」で赤固定になることを確認（未実施）。

点滅の目視テスト：上記の描画ツールをcompile後、`build/render-status --live-alert-preview` を実行。実アプリと同じStatusStripをテスト値で別windowに表示し、2分後またはwindowを閉じると終了する。BAT/SSD/GPU温度の赤は1秒ごとの濃淡、黄色は固定が合格。「視差効果を減らす」有効時は赤固定。実アプリの監視値・履歴・設定には書き込まない。

RAM残りは `testAvailableMemoryUsesSameEstimateAndRejectsInvalidValues` で総量と使用量の差、実際の0、欠損・不整合・単位不正を検証。

## ポップオーバー

`tools/RenderDashboard.swift` は同じDashboardを通常ユーザーの実サンプルでオフスクリーン描画する。デスクトップ操作の成功とは区別する。

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" xcrun swiftc -parse-as-library Sources/MonitorKit/Core/*.swift Sources/MonitorKit/Monitoring/*.swift Sources/MonitorKit/Utilities/*.swift Sources/MyToolBox/App/MonitorStore.swift Sources/MyToolBox/App/ToolCatalog.swift Sources/MyToolBox/UI/Dashboard.swift Sources/MyToolBox/UI/SettingsPanel.swift Sources/MyToolBox/UI/AppTheme.swift Sources/MyToolBox/UI/Theme*.swift Sources/MyToolBox/UI/ToolLauncher.swift tools/RenderDashboard.swift -o build/render-dashboard
build/render-dashboard
```

実機受け入れ：メニューをクリックして小型一覧が開く、各カード→詳細→戻る、設定までスクロールして表示、外側クリックと再クリックで閉じる、再表示は一覧、閉じても履歴が継続、一覧・モニターに終了ボタンがなく、⌘Qでも終了せず、アプリメニューの終了確認で「監視を続ける」を選べる。ログイン起動の登録はこの表示確認では操作しない。実機操作は未検証。

アイコン更新時：`python3 scripts/build_icon.py` → `python3 scripts/generate_project.py` → Full。生成.appのInfo.plistのCFBundleIconFileと同梱ICNSを照合し、`iconutil -c iconset` で復号できることを確認。Finderのキャッシュ更新はOSに依存し、ファイル同梱確認と目視を区別する。

定期ログはMonitoringLogTestsで記録間隔・復帰基準・欠損の保持・停止・保存期間・無関係ファイル保持・設定永続化と不正値補正・書込失敗を検証。実機では10秒超待ち、JSONL行数増加と状態・単位を確認。ログイン登録状態の確認は再ログインでの起動確認と区別する。

ツール一覧：専用の四角グリッドアイコン→システムモニター→下端のツール一覧、数値表示→モニター直行、一覧側のモニター設定、外側クリックで閉じる、Finderから再度開くと通常の一覧ウィンドウ、を実機で確認する。Dock再クリック・最小化からの復帰・一覧の×後も監視継続・メニューからウィンドウ表示・ログイン時は一覧非表示・両一覧のお気に入り同期も確認する（Dockから一覧を開く操作は2026-10-20にユーザーが実機確認済み。他の項目は個別に確認が必要）。どちらの入口も同一Storeを使い、監視・ログを二重に起動しない。描画ツールはtools画面も保存する。可変ウィンドウは最小サイズと拡大サイズで内容の追従・スクロールを確認し、実機の端のドラッグ・小型時のスクロール・一覧の列数追従は2026-10-20に確認済み。再起動後の位置／サイズ復元は未検証。

## ローカル5ツール

LocalToolsTestsとTextToolsTestsを含む全58件。CSV引用符/改行/末尾空行/Unicode/Shift_JIS/上限、不正入力、公表済み祝日/独自休日/期間境界、左右信号/フェード/RMSを検証。手動操作の合否基準は[ローカルツール](docs/LOCAL_TOOLS.md)。音声のテストは信号の純粋計算のみで、スピーカー再生やマイク許可を自動実行しない。

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" xcrun swiftc -parse-as-library Sources/MonitorKit/Tools/*.swift Sources/MonitorKit/Core/VisualTheme.swift Sources/MonitorKit/Core/ToolFavorites.swift Sources/MyToolBox/App/ToolCatalog.swift Sources/MyToolBox/UI/AppTheme.swift Sources/MyToolBox/UI/Theme*.swift Sources/MyToolBox/UI/ToolLauncher.swift Sources/MyToolBox/Tools/*.swift tools/RenderLocalTools.swift -o build/render-local-tools
build/render-local-tools
```

evidence/tool-*.pngの16画面をオフスクリーン描画。CSVは合成データ、音声/マイクは未開始。Info.plistのマイク用途、署名のaudio-input entitlement、bundleのJapaneseHolidays.jsonも確認する。新UIの一覧→営業日と1週間計算は実機操作・目視済み。GUI全体・実録音・装置切替・sleepは別途未検証。

## テキスト系・CSV実操作

TextToolsTestsは連番の整数境界、クリップボードの列選択/清掃/引用、Markdown/SQL、クリーナーとCSV実ファイルの往復を検証。[テキスト仕様](docs/TEXT_TOOLS.md)。RenderLocalToolsは新3画面も同じコマンドで描画する。

実CSV試験はevidence/csv-uiに作業用ファイルを保存し、NSOpenPanel/NSSavePanelを実操作。日本語・カンマ・二重引用符・セル内改行を編集→保存→再読込→ファイル解析で一致を確認。貼り付けとセル編集の併用でも全操作へスクロール到達できること、ダブルクリックした表セルに入力できること、保存直前の入力が反映されることを確認する。元ファイルを変更せず別名で保存する。

## 行・検索置換・リスト

LineUtilityTestsの11件を追加。[拡張仕様と実機結果](docs/LINE_TOOLS.md)。標準verifyに含まれる。RenderLocalToolsは3つの行モード・検索置換・リストモードも描画。

正規表現の進捗中断を任意検証（通常設定を変えない）：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" xcrun swiftc -parse-as-library Sources/MonitorKit/Tools/*.swift tools/RegexBudgetProbe.swift -o build/regex-budget-probe
build/regex-budget-probe
```

これは専用の悪条件入力で0.25秒予算を確認する。初回実行は外側の3秒subprocess timeoutも付け、evidence/regex-budget.txtへ記録。OS/ICUの全パターンに厳密な実時間上限を保証するものではない。

## 比較ツール・Gitからの初回ビルド

ComparisonTestsの7件は空行・末尾改行・行番号・語単位/Unicode差分、ランダムな行列の再構築、1,000行境界・容量超過、集合の順序/重複/大文字小文字/空白を検証する。Fullに含む。合成描画2画面と実機操作の結果は[比較ツール](docs/COMPARISON_TOOLS.md)。

Python検証器テストは7件（証明書署名からad hocへの逆戻り拒否・独立ツールのID／実行ファイル検証を含む）。Fastは未生成の宣言済みRelease.appリンクだけ許容する。他の欠落リンクは失敗し、build内の参照clone文書は走査しない。Fullは必ず実ビルドと.app・署名を確認する。生成物をGitへ入れず初回checkoutから検証できるための例外であり、アプリ検証の省略ではない。


## 共通テーマ

`VisualThemeTests`は旧設定からの既定値・全テーマ永続化・不正値fallbackと監視設定非干渉を検証する。

```sh
python3 tools/render_themes.py --render --probe
```

4テーマ×20ツール画面＋5モニター画面を`evidence/themes/<theme-id>/`へ保存。描画は引数のoverrideを使用し、ユーザーのテーマ設定へ書き込まない。ThemeSwitchProbeは隔離UserDefaultsを使い、2つの保持したwindowへの同期、入力状態・onAppear回数維持、native chrome復帰、新rootの保存値復元を検証。実デスクトップのクリック・キーボード操作とは区別する。

## テキスト変換・文字チェック

TextCodecTestsでUTF-8 Base64の往復／不正形式／非UTF-8、エスケープの往復と未知の並びの保持、可視化、Unicodeの文字種・行番号・詳細1,000件上限・入力上限を検証。RenderLocalToolsにtext-codec／text-inspector／text-visualizerを追加。テーマ導入後の描画コンパイルはCore/VisualTheme.swiftとUI/Theme*.swiftも含める。実機では一覧→テキスト変換、4モードの切替とコピー、クリーナー3モードの切替とコピーを確認する（今回未実施）。


Windows 98のCSV画面は、NSHostingView.cacheDisplayの合成画像でAppKit表の周囲が透過になることがある。実画面の欠落とは区別し、CSV表は実デスクトップでも確認する。テーマ変更後の描画確認はスクリーン上の表示を優先する。


## カレンダー候補

ScheduleCandidatesTestsは単一／複数選択、同日再選択、月年をまたぐ並び順、最早日の保持、日別時間と既定時間の分離、解除／再選択、時刻不正時の全出力停止、うるう日とUTC/JST境界、時間バーの両端／逆順／同一点／範囲外／キャンセルを検証。LocalToolsTestsの営業日・独自休日テストも継続する。RenderLocalToolsのcalendar-candidatesは3候補・日別時間・会社休日を含む固定データで3テーマを描画する。

実機では一覧→カレンダー、複数候補追加→時間変更→コピー、月切替と選択保持、営業日モードへ往復して入力と独自休日を保持、時間バーの9→21・逆順・同一点・キャンセル・選択途中のコピー不可、3テーマ切替を確認する。結果は[sessions](sessions/README.md)へ記録する。

カラーパレット：PaletteColorTestsで3/6桁HEX・不正入力・RGB境界・120色の数/重複・おすすめCSSを検証。実機では一覧から起動、色選択・入力・HEX/RGB/CSSコピー、方向/おすすめ切替、閉じて再起動後のメモ保持を確認する。

User-Agent Viewer：UserAgentInfoTestsでブラウザ識別優先順、iOS/Android/ChromeOS、WebKitとSafariの区別、未知UAを検証。実機では一覧→起動・更新・UA/全情報コピー・別UA貼付け・3テーマを確認する。

描画ツールを上記手順でcompile後、`build/render-local-tools --user-agent-probe`でローカルWebKitのUA・15項目・レポートを検証。`build/render-local-tools blue-cosmos --user-agent-only`で対象画面だけ描画できる。WebKitのプロセス起動がsandboxに拒否された場合は通常ユーザー環境で実行する。

## 画像リサイズ

ImageResizerTestsで一括の縦横比／固定寸法／倍率・別フォルダ同名画像・不正画像の失敗分離・既存出力の上書き拒否と、PNG寸法/透明・JPEG白背景/形式・EXIF向き補正・寸法/画素/入力上限・倍率丸め・複数ページ拒否・実ファイル保存再読込・元画像/シンボリックリンク/ハードリンク保護を検証する。`tools/RenderImageResizer.swift`はRenderLocalToolsのcompileコマンドの末尾ソースと出力名を置き換えてcompileし、`build/render-image-resizer`で実行。合成画像によるモデル読込・縦横比・変換・JPEG保存再読込・元画像不変・古い結果破棄と3テーマ描画を確認する。手動では一覧から起動、ファイル選択/ドロップ、幅/高さの双方向編集、倍率/品質/形式、保存キャンセル/別名保存を確認する。

計算5ツールはTechnicalCalculatorsTestsで単位・多桁進数・帯域逆算・RAID制約・SLA境界を検証。RenderLocalToolsに`--calculators-only`を付けて5画面を描画。計算5ツールの実機代表入力・コピー・不正入力を確認済み（[記録](sessions/2026-10-15-32-calculators-installed.md)）。

一覧のカテゴリ・検索は[実機記録](sessions/2026-10-15-33-launcher-categories.md)。RenderLocalToolsの`--launcher-only`で一覧だけ描画できる。検索の一致／0件／解除、カテゴリ件数、結果からの起動を実機で確認する。

お気に入りはToolFavoritesTestsで集合の追加・解除・破損・重複・永続化を検証。実機の登録→先頭表示→再起動保持→起動→解除は[記録](sessions/2026-10-15-34-tool-favorites.md)。

お気に入りの順序はToolFavoritesTestsで前後移動・無効移動・追加解除・UserDefaults再読込を検証。実機ではアイコンを前後／別行へドラッグ、絞り込み中の順序、再起動保持を確認する。[今回の実機ドラッグ制限](sessions/2026-10-15-35-favorite-reordering.md)。

誤終了防止は[実機記録](sessions/2026-10-15-36-prevent-accidental-quit.md)。一覧の終了ボタン消失、⌘Q無効、メニューの確認から継続、画面閉鎖後のログ増加を確認。

## 時間ツール

保留を解除し一括検証を実施（末尾の記録参照）。TimeToolsTestsの日時差分・一時停止／再開・保存復元・日付またぎ・入力検証に加え、4画面の3テーマ、ボード12個・複製／移動／削除・保存・スリープ復帰・ポモドーロ完了回数／日付変更・会議の2操作開始・時間計算コピーを確認する。[仕様](docs/TIME_TOOLS.md)。

ローカルメモ：自動／モデル検証を実施（末尾の一括検証参照）。[後日のテスト項目](docs/LOCAL_MEMO.md)にJSON互換・履歴・永続化・障害・UIの未実施項目を集約。

ポート番号検索・HTTPステータス一覧：自動／モデル検証を実施（末尾の一括検証参照）。[後日のテスト項目](docs/NETWORK_REFERENCE.md)に検索・分類・データ・UI・ビルド確認を集約。

ハッシュ・テストデータ生成：自動／モデル検証を実施（末尾の一括検証参照）。[後日テスト](docs/DEVELOPER_GENERATORS.md)にSHA既知値・UUID v4・生成制約・CSV往復・キャンセル・UI確認を集約。

サーバー・ネットワーク・日常計算11本：自動／モデル検証を実施（末尾の一括検証参照）。[マージ後のテスト項目](docs/SERVER_AND_EVERYDAY_TEST_PLAN.md)にロジック境界値・正常/異常系・3テーマ・永続化・ビルドの未実施項目を集約。参照元の不足補完分は[照合記録](docs/SERVER_AND_EVERYDAY_PARITY.md)に追加。

ログハイライター：LogHighlighterTestsでレベル判定・改行・前後行・検索を検証。実機では3テーマ、検索の前後移動、フィルター後のコピー、折り返し、2 MB超過時の案内を確認する。

JSONツール：`JSONWorkspaceTests`で数値精度・JSON往復・構文／Unicode／重複キー・CRLFと行列・入力上限・部分木編集・ファイル往復／BOM／入出力失敗を検証。`tools/RenderJSONWorkspace.swift`でモデルの読込・編集・保存・失敗時保持と3モード×3テーマを検証。実機受け入れは[JSON仕様](docs/JSON_TOOLS.md)。

## 正規表現・表・CSV統計

`RegexAndSmallDataTests.swift`でUnicode・キャプチャ・置換・フラグ・空一致・不正入力・部品生成・表の各形式・欠損／混在／重複／数値統計を検証。描画はRenderLocalToolsのコンパイル末尾を`tools/RenderDataWorkbench.swift -o build/render-data-workbench`へ置換し実行。4画面×3テーマを確認する。手動ではテスターの入力変更／コピー、条件追加／並べ替え、表の編集／保存、CSV読込／NULL条件変更を確認する。[仕様](docs/DATA_WORKBENCH.md)。

SQLツール：SQLToolsTestsで引用保持・整形の実行結果一致・SELECT説明・メモリ内SQLite・ロールバック・外部操作拒否・実行上限を検証。[実機確認項目](docs/SQL_TOOLS.md)。

## 追加ツールの一括検証

[実行記録](sessions/2026-10-15-49-batch-tool-validation.md)。AddedToolsTests／ServerAndEverydayTestsを標準Swiftテストに追加。`tools/VerifyAddedTools.swift`は全Sources（ProbeとMyToolBoxAppを除く）と一緒にコンパイルし`build/verify-added-tools`で実行。合成ファイル・隔離UserDefaultsによる保存失敗／復旧・モデル遷移と3テーマ描画を行う。画面は`build/added-tools-preview/`、ログは`build/validation/added-tools-probe.log`。実機の全操作とは区別する。

表ビルダー：`testSavedTableCSVReopensExactly`で実ファイルのUTF-8／BOM付きCSVの往復、日本語・引用符・セル内改行・末尾空欄、サイズ／行数／構文エラーを検証。保存3形式、windowを閉じた後のCSV再読込、保存キャンセルの保持は[実機記録](sessions/2026-10-15-50-table-file-roundtrip.md)。

残る実機確認：[メモJSON往復・表の実表示／編集／コピー・SQL復帰・ログ／classic close修正](sessions/2026-10-15-52-remaining-live-fixes.md)。ThemeSwitchProbeは終了拒否とclose／cleanup各1回も確認。IME未確定・全組合せ・実sleep等は未確認として区別する。

マイカレンダー：`PersonalCountdownTests.swift`で暦日差・時間目標・保存／破損を確認。`tools/VerifyPersonalCalendar.swift`で隔離モデルの追加・編集・復元・削除、ショートカットキー保存と不正キー拒否、分離した2ツール×3テーマ描画。実機でカレンダーのショートカットON/OFF・キー変更・他アプリからの表示・再起動後の復元を確認する。実機では日付選択→目標追加→編集→閉じて再表示→削除確認→キャンセルを確認する。[仕様](docs/PERSONAL_CALENDAR.md)。

セキュリティ：SecurityTestsで既知／未知応答、権限・終了コード・stderr・移行状態、子プロセスtimeout／起動失敗を確認。手動ではモニター→セキュリティ→再確認の確認中／連打防止／日時更新を確認。設定変更による試験は行わない。[仕様と制約](docs/SECURITY.md)。

ウィンドウ配置：`WindowLayoutTests`で端数・負座標・座標反転・中央配置を検証。手動で権限なし案内→ユーザーによる許可→半分／三分割／四分割／復元、複数画面、固定サイズ拒否、ショートカットON/OFF・再起動保持を確認。[仕様](docs/WINDOW_MANAGER.md)。

Git一括管理：`GitBatchTests`でローカルbare origin／2cloneの同期・停止条件と引数の安全性を検証。実リモートへは送信しない。UIは選択・確認キャンセル・処理中閉鎖抑止・3テーマを別途確認。[仕様](docs/GIT_BATCH.md)。

クイックメモ：tools/VerifyQuickMemo.swiftを他のツールプローブと同様に全Sources（Probe・MyToolBoxAppを除外）とコンパイル。Native入力・保存復元・Undo/Redo・別メモのUndo分離・保存失敗保護・3テーマを確認。実機IME・テキスト入出力パネル・物理グローバルキーは別途確認。[仕様](docs/LOCAL_MEMO.md)。

拡大カレンダー：CalendarAlmanacTestsが写真の2027年1月の六曜・節気・朔望、正午月齢／JST日界、2025年閏6月、範囲外を検証。VerifyPersonalCalendarは拡大版も3テーマ描画する。実機は小型→拡大→前後月／周辺月→日付選択→小型へ戻るを確認。

雨雲レーダー：Fast → Full後、専用メニューから地図読込・拡大縮小・移動・時刻選択／再生・更新・外側／×でclose・再表示時の地域保持と最新時刻・既存一覧／モニターとの切替を確認する。オフライン時の再試行も確認。外部Web画面の地図タイル失敗はトップページの読込完了とは別に目視確認する。

## メモ・タイマーの独立プロセス

Fast → Full、検証器テストと対象4ヘルパーの個別署名を確認する。実機では一覧から4本起動、メモ編集・各タイマー開始、本体の正常終了と再起動、ヘルパーPID不変・内容／計測継続、再選択で重複しないこと、本体停止中の操作、ツール個別終了、メモショートカットの登録移譲と再取得を確認する。保存失敗保護はVerifyQuickMemoの隔離モデル検証を併用。結果は[sessions記録](sessions/2026-10-20-independent-tools.md)。

天気数値：`JMAWeatherTests`で品質フラグ・実測0・欠測／不正値・JST日界・対象日なしを検証。`tools/VerifyWeather.swift`を全Sources（Probe／MyToolBoxAppを除外）とコンパイルし、隔離設定の実画面モデルで実取得・地域切替／保存・連続切替・4テーマのオフスクリーン描画を確認する。[仕様](docs/WEATHER.md)。

天気メニュー：JMAWeatherTestsが取得中・欠測・負の気温・0・30分の期限を検証。VerifyWeatherはWebViewなしの共通モデルで自動更新／二重開始抑止／停止／失敗時の部分成功、実際のupdateMenuButtonによるNSButton描画を確認。コンパイル対象は[天気仕様](docs/WEATHER.md)。本番メニューバーの実クリック・sleep/wakeは未確認を区別する。

天気2段表示：VerifyWeatherで本番と同じWeatherMenuStripを含むボタンを描画し、上段の°C／下段の%・アイコン・上下の欠けを目視確認。繰り返し更新でサブビューが増えないことを確認する。

## カレンダー独立プロセスのバックグラウンド検証

`tools/VerifyIndependentShortcuts.swift`は本番のToolShortcutModel／IndependentShortcutCoordinatorへテスト用登録境界を注入し、隔離UserDefaultsで所有移譲・本体モデル再作成・最新キー再読込・起動失敗・終了通知・登録競合時の意図保持を検証する。OSホットキー登録や本番ウィンドウ操作は行わず、実機でキーが届くことの証拠とはしない。

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" xcrun swiftc -parse-as-library Sources/MyToolBox/App/ToolCatalog.swift Sources/MyToolBox/Tools/IndependentTools.swift Sources/MyToolBox/Tools/ToolShortcutModel.swift tools/VerifyIndependentShortcuts.swift -o build/verify-independent-shortcuts
build/verify-independent-shortcuts
```

VerifyPersonalCalendarは隔離モデルの目標保存／編集／復元／破損保護・祝日読込と4テーマ×小型／拡大／カウントダウンのオフスクリーン描画。コンパイル時はMonitorKitのCore／Monitoring／Utilities／Tools、ToolCatalog、AppTheme／Theme*、MyToolBox/Tools全ファイルと`-lsqlite3`を含める。Fullは6つのhelperのID・実行ファイル・deep署名とカレンダー祝日データ一致まで確認する。本番の起動／終了／配置はしない。[実行結果](sessions/2026-10-20-independent-calendars.md)。

天気アイコン：JMAWeatherTestsが晴れ／くもり／雨／雪・複合予報・未知文言・JST日界の失効を検証。VerifyWeatherが実予報とメニューの接続、予報失敗時の観測値保持とunknown、5種類のネイティブ描画（合成の天気状態）を確認。

アイコン縦横比：VerifyWeatherで5種類の実SF Symbolの元サイズと描画矩形の比率が一致し、16pt枠内に収まることを確認。menu-icons-aspect-fit.pngで雲の形・中央配置・欠けを目視確認する。

## 独立JSON・CSVのバックグラウンド検証

`tools/VerifyIndependentDocuments.swift`は実際のJSONWorkspaceModel／CSVModelへ未保存確認の判断だけを注入する。隔離ファイルで読込・編集・閉じるキャンセル・処理中の終了拒否・保存／再読込・不正JSON／保存先エラー時の内容保持を確認する。CSV閲覧／編集のモデル分離と閲覧の書込禁止も確認。NSAppはprohibited、AppStorageは隔離し、ファイルパネル・実キー・本番アプリ・クリップボードは操作しない。4テーマ×JSON／CSV閲覧／CSV編集の12画面をオフスクリーン描画する。

コンパイル対象はMonitorKit/Core/VisualTheme、ToolsのCSVDocument／BusinessDays／JSONWorkspace／TextTools／TextCodec、ToolCatalog、AppTheme／Theme*、MyToolBox/ToolsのToolDesign／IndependentTools／JSONWorkspaceView／CSVTool／TextToolViews／TextCodecViewとプローブ。`swiftc -parse-as-library`でbuild/verify-independent-documentsを生成して実行する。並行編集時は対象ソースを一時コピーして固定する。Fullは新3本を含む9helperのID・実行ファイル・deep署名を確認。[結果](sessions/2026-10-20-independent-json-csv.md)。

天気アイコン色：VerifyWeatherで本番WeatherMenuStripの全5状態をAqua／Dark Aquaの両方で描画し、晴れの橙・雨の青・数値の可読性・縦横比維持を目視確認する。

## 独立画像・Gitのバックグラウンド検証

`tools/VerifyIndependentImageGit.swift`で実モデルの画像読込・設定・変換・保存・元画像保護・一括処理の失敗後継続と結果保持を確認。GitはUUID付き隔離先にbare origin・2cloneを作り、root設定引継ぎ・処理中のcanClose／重複実行拒否・確認キャンセル・コミット／ローカルpush・ff更新・読込失敗の復帰を確認する。実行確認の判断だけを注入し、外部リモート・ユーザーrepo・本番設定・クリップボードは操作しない。NSAppはprohibited、画像／Gitの4テーマ×単一画像・一括画像・Gitの12画面をオフスクリーン描画。

コンパイル対象はMonitorKit/Core/VisualTheme、ToolsのCSVDocument／BusinessDays／ImageResizer／GitBatch、ToolCatalog、AppTheme／Theme*、MyToolBox/ToolsのToolDesign／IndependentTools／ImageResizerView／GitBatchViewとプローブ。`swiftc -parse-as-library`でbuild/verify-independent-image-gitを生成し実行。並行編集時は必要な実ソースを一時コピーして固定する。Fullは全11helperのID・実行ファイル・deep署名、Python検証器は新2本の欠落拒否まで確認。[結果](sessions/2026-10-20-independent-image-git.md)。

降水確率：JMAWeatherTestsで同じ区域のpops選択、現在を含む6時間枠、0%・欠測・範囲外・配列不足、18–24時と翌0時、枠終了時の除外を検証。VerifyWeatherが実取得と4テーマ描画を確認する。

## 独立ウィンドウマネージャーのバックグラウンド検証

RenderWindowManagerは実際のWindowManagerModelへ登録境界・信頼読込・配置先境界を注入し、アプリ追跡を無効化する。16物理キーの保持・モデルへの配送、常駐／非表示起動の条件、親再作成時の不干渉、明示OFF／停止、競合・部分登録の解除／希望ON保持と再試行、親／helper対象除外、権限なし案内を検証する。実OSホットキー登録・AX書込み・TCC操作・本番アプリ起動はしない。NSAppはprohibited、AppStorageは隔離、4テーマをオフスクリーン描画。

コンパイル対象はMonitorKit/Core/VisualTheme、ToolsのCSVDocument／BusinessDays／WindowLayout、ToolCatalog、AppTheme／Theme*、MyToolBox/ToolsのToolDesign／IndependentTools／WindowManagerShortcuts／WindowManagerViewとRenderWindowManager。`swiftc -parse-as-library`でbuild/render-window-managerを作り実行。Fullは12helperのID・実行ファイル・deep署名。実キー・本体再起動・非表示起動・AX許可維持は別の実機項目として残す。[結果](sessions/2026-10-20-independent-window-manager.md)。

## 全55ツールの独立起動のバックグラウンド検証

`tools/VerifyAllIndependentTools.swift`を全Sources（Probe／MyToolBoxAppを除外）と`-parse-as-library -lsqlite3`でコンパイルし、`build/verify-all-independent-tools`を実行。起動・表示・終了境界を注入した実ToolWindowsで全ToolIDの配送、通常close／拒否／cleanupと常駐条件を確認する。モデルは隔離UserDefaults、MonitorStoreは自動起動なしで設定／所有境界を確認し、4テーマ×モニター2画面を非表示描画。NSAppはprohibited。本番アプリ・LaunchServices・実キー・録音・音声・AXは操作しない。

Fullは全カタログhelperのID・実行ファイル・祝日・マイク用途文・deep署名・マイク音声入力entitlementを確認。Python負例で全helperの欠落とマイク用途文の欠落も拒否する。実起動・PID維持・権限・各画面の実操作は別途未検証として記録。[結果](sessions/2026-10-20-all-independent-tools.md)。

## デプロイ安全性の回帰

`python3 scripts/test_deploy.py`：親不在の常駐helper・開発コピーによる配置拒否、事前検査の無変更、コピー中の起動による中止、配置検証失敗時の復旧、配置後起動時の旧版保持、成功時の整理を隔離フォルダで確認する。実プロセスの終了・本番配置はしない。

## OS保護の検証

`python3 scripts/test_protected_deploy.py` はリンク拒否・root所有境界・全プロセス停止・署名不一致拒否・新helper署名固定を通常権限で確認する。Fast／Fullに含む。実OSの拒否試験は管理者が初回導入する際、一時領域のfixtureにのみ実施する。実行不能なら導入済みと扱わない。[運用](docs/PROTECTED_DEPLOYMENT.md)。
