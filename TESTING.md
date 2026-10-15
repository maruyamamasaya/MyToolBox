# Testing

## Test Strategy
文書・Swiftロジック・ネイティブXcodeビルドを標準verifyで検証する。手動UI・実機試験・比較は別管理で、自動verify成功と混同しない。外部依存パッケージ・外部通信なし。

## Fast Validation

```sh
python3 scripts/verify.py --fast
```

必須文書・構造・リンクとSwift単体テストを実行。設定変更・OS実機操作を行わない。

## Full Validation / 標準Verify

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

ツール一覧：専用の四角グリッドアイコン→システムモニター→下端のツール一覧、数値表示→モニター直行、一覧側のモニター設定、外側クリックで閉じる、Finderから再度開くと一覧、を実機で確認する。どちらの入口も同一Storeを使い、監視・ログを二重に起動しない。描画ツールはtools画面も保存する。

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

Python検証器テストは5件。Fastは未生成の宣言済みRelease.appリンクだけ許容する。他の欠落リンクは失敗し、build内の参照clone文書は走査しない。Fullは必ず実ビルドと.app・署名を確認する。生成物をGitへ入れず初回checkoutから検証できるための例外であり、アプリ検証の省略ではない。


## 共通テーマ

`VisualThemeTests`は旧設定からの既定値・全テーマ永続化・不正値fallbackと監視設定非干渉を検証する。

```sh
python3 tools/render_themes.py --render --probe
```

3テーマ×20ツール画面＋5モニター画面を`evidence/themes/<theme-id>/`へ保存。描画は引数のoverrideを使用し、ユーザーのテーマ設定へ書き込まない。ThemeSwitchProbeは隔離UserDefaultsを使い、2つの保持したwindowへの同期、入力状態・onAppear回数維持、native chrome復帰、新rootの保存値復元を検証。実デスクトップのクリック・キーボード操作とは区別する。

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

ImageResizerTestsでPNG寸法/透明・JPEG白背景/形式・EXIF向き補正・寸法/画素/入力上限・倍率丸め・複数ページ拒否・実ファイル保存再読込・元画像/シンボリックリンク/ハードリンク保護を検証する。`tools/RenderImageResizer.swift`はRenderLocalToolsのcompileコマンドの末尾ソースと出力名を置き換えてcompileし、`build/render-image-resizer`で実行。合成画像によるモデル読込・縦横比・変換・JPEG保存再読込・元画像不変・古い結果破棄と3テーマ描画を確認する。手動では一覧から起動、ファイル選択/ドロップ、幅/高さの双方向編集、倍率/品質/形式、保存キャンセル/別名保存を確認する。

計算5ツールはTechnicalCalculatorsTestsで単位・多桁進数・帯域逆算・RAID制約・SLA境界を検証。RenderLocalToolsに`--calculators-only`を付けて5画面を描画。計算5ツールの実機代表入力・コピー・不正入力を確認済み（[記録](sessions/2026-10-15-32-calculators-installed.md)）。

一覧のカテゴリ・検索は[実機記録](sessions/2026-10-15-33-launcher-categories.md)。RenderLocalToolsの`--launcher-only`で一覧だけ描画できる。検索の一致／0件／解除、カテゴリ件数、結果からの起動を実機で確認する。

お気に入りはToolFavoritesTestsで集合の追加・解除・破損・重複・永続化を検証。実機の登録→先頭表示→再起動保持→起動→解除は[記録](sessions/2026-10-15-34-tool-favorites.md)。

お気に入りの順序はToolFavoritesTestsで前後移動・無効移動・追加解除・UserDefaults再読込を検証。実機ではアイコンを前後／別行へドラッグ、絞り込み中の順序、再起動保持を確認する。[今回の実機ドラッグ制限](sessions/2026-10-15-35-favorite-reordering.md)。

誤終了防止は[実機記録](sessions/2026-10-15-36-prevent-accidental-quit.md)。一覧の終了ボタン消失、⌘Q無効、メニューの確認から継続、画面閉鎖後のログ増加を確認。

## 時間ツール（実行保留）

ユーザー指定で今回のFast／Full・単体・実機UIテストは後日実施。TimeToolsTestsの日時差分・一時停止／再開・保存復元・日付またぎ・入力検証に加え、4画面の3テーマ、ボード12個・複製／移動／削除・保存・スリープ復帰・ポモドーロ完了回数／日付変更・会議の2操作開始・時間計算コピーを確認する。[仕様](docs/TIME_TOOLS.md)。

ローカルメモ：今回はユーザー指示で全検証を保留。[後日のテスト項目](docs/LOCAL_MEMO.md)にJSON互換・履歴・永続化・障害・UIの未実施項目を集約。

ポート番号検索・HTTPステータス一覧：ユーザー指示で全検証を保留。[後日のテスト項目](docs/NETWORK_REFERENCE.md)に検索・分類・データ・UI・ビルド確認を集約。

ハッシュ・テストデータ生成：ユーザー指示で全検証を保留。[後日テスト](docs/DEVELOPER_GENERATORS.md)にSHA既知値・UUID v4・生成制約・CSV往復・キャンセル・UI確認を集約。
