# Current

更新日：2026-10-16（日本時間）
## Project
MyToolBox：ローカル完結のmacOSツール集。最初のツールはM1 Max向けシステムモニター。目的はParallels Toolboxからの段階的な移行。
## 現在のフェーズ
Phase 1の主要指標PoCとPhase 2初期MVPを実装。Phase 3の自動テスト・ビルドを実行。移行完了ではない。
52ツールを/Applicationsへ反映・再起動済み。単体150件／Full・署名・全ファイル一致確認。直近は[ウィンドウマネージャー配置](sessions/2026-10-16-07-window-manager-install.md)。

## 実装済み
- [Git一括管理](docs/GIT_BATCH.md)：フォルダ直下の状態確認・ff更新・確認付きコミット／送信。既存スクリプトは保持。単体152件・Full・3テーマ描画成功。/Applications反映・再起動・一覧52件を実画面で確認。個別画面の操作は未確認。
- [ウィンドウマネージャー](docs/WINDOW_MANAGER.md)：16配置・復元・ショートカット。許可反復へ証明書署名固定・保守処理の設定変更を修正し配置済み。単体152件／Full成功。初回署名切替の再許可・維持確認待ち。[記録](sessions/2026-10-16-10-stable-signing.md)。
- [セキュリティ状態](docs/SECURITY.md)：モニター内でFirewall／FileVault／Gatekeeperを起動時・手動確認。通常権限・各5秒timeout、失敗理由・日時・確認中・移行中を表示。/Applicationsへ配置、実機でFileVault有効と再確認2回を確認。
- [マイカレンダー](docs/PERSONAL_CALENDAR.md)：独立した月表示と、自分で複数設定できる日付／時間目標の残り日数。ローカル保存・編集・削除。既存の予定調整は「日程調整・営業日」へ表示名変更。
- [共通3テーマ](docs/THEMES.md)：Blue Cosmos／Living Aurora／Windows 98。設定・一覧・各ツールから切替、開いている全画面へ反映・永続化。
- 専用メニューアイコンから実装済みツールを6カテゴリで表示。カテゴリ絞り込み・名前／用途の検索、星でお気に入り登録・先頭表示・ドラッグ並べ替え・再起動後の保持に対応。従来の数値メニューも維持。通常画面の終了ボタンと⌘Q終了を除き、意図的な終了はメニューから確認。
- モニター以外のツールは独立window。カード型の共通UI、公式祝日データ同梱、音声は明示開始・録音メモリ内、CSVは明示保存。[初期5本](docs/LOCAL_TOOLS.md)、[テキスト3本](docs/TEXT_TOOLS.md)、[行・置換・リスト5機能](docs/LINE_TOOLS.md)。
- [カレンダー](docs/CALENDAR.md)：日程候補の作成と営業日計算を統合。9〜21時のバーで時間帯をクリック選択・範囲表示・コピー、公式祝日／独自休日を共有。
- Base64／エスケープ変換を追加。クリーナーに文字チェック／空白・改行の可視化を統合。[仕様](docs/TEXT_TOOLS.md)。
- 行ソート/抽出/重複は3タブに統合、リスト変換は表整形の別モード。検索/置換はICU正規表現・複数ルール・進捗による時間上限に対応。
- [比較ツール](docs/COMPARISON_TOOLS.md)：テキスト差分・リスト比較を統合。空行追加・集合3列・左右入替の実機操作を確認。
- CSVは実際の編集・保存・再読込を検証。貼付け/編集欄のはみ出し、表内編集フォーカスを修正。
- CPU全体／P/E／各コア、GPU全体使用率・基本情報、RAM、単一IFの通信量、APFS容量、Disk I/O、Batteryの主要値。
- M1 MaxのCPU全体/P/E・GPU温度、ファン2基の実回転数（SMC読み取り専用、5秒周期）。
- App/Core/Monitoring/UI/Utilities、直列actor取得、sleep/wake基準リセット、60秒履歴、設定永続化。
- メニューは仕切り線なし、FANの右にRAM残り（RAMスティックアイコン）・CPU温度・GPU温度（文字のみ）を1段表示で集約。使用率などは2段表示。
- メニュー注意色（BAT 50%以下黄色／20%以下赤など）・赤の明滅、動きを減らす設定に対応。
- メニューバーから小型ポップオーバー（一覧カード→7詳細／設定、外側クリックで閉じる）・グラフ・設定・順序／表示／単位／周期・明示操作によるログイン起動UI。
- /Applicationsへ配置、ログイン起動の有効状態確認。定期ログ（10秒・7日、ローカルJSONL、設定変更可）。
- 専用アプリアイコン（工具箱＋モニター波形、16〜1024px ICNS）。
- Xcodeプロジェクト、ローカル.app、Swift Packageの共通ライブラリ・CLI PoC・単体テスト、標準verifyのアプリ検証。
- カラーパレット：参照Web版の120色、HEX/RGBコピー、2色・4方向のCSSグラデーション、8おすすめ、ローカル自動保存メモ。

- [User-Agent Viewer](docs/USER_AGENT.md)：内蔵WebKitの端末情報・UA／全情報コピー・外部UA貼り付け解析。

- [画像リサイズ](docs/IMAGE_RESIZER.md)：複数選択／複数drop・ピクセル／倍率指定・縦横比維持・プレビュー・JPEG/PNG一括保存。

- [容量・進数・帯域・RAID・SLAの5計算ツール](docs/TECHNICAL_CALCULATORS.md)を追加。ローカル計算、入力検証、結果コピー、3テーマ対応。/Applications版へ配置し、5本の代表入力・コピー・不正入力を実機確認。

- [時間ツール4本](docs/TIME_TOOLS.md)：ポモドーロ、最大12個のタイマーボード、2操作で開始できる会議タイマー、勤務時間／時間帯合計。全体テスト・ビルド・配置済み。開始・停止・保存復元・日付またぎを専用プロセスで実機確認。

- [ローカルメモ](docs/LOCAL_MEMO.md)：複数メモ・自動保存・5世代履歴・JSON交換を実装。全体テスト・ビルド・配置済み。専用保存先で編集・保存・再表示・履歴を実機確認。

- [ポート番号検索・HTTPステータス一覧](docs/NETWORK_REFERENCE.md)：ローカル検索・分類・コピーを追加。全体テスト・ビルド・配置済み。検索・絞り込み・0件表示を専用プロセスで実機確認。

- [乱数ジェネレーター](docs/RANDOM_NUMBERS.md)：範囲・1〜32桁・0始まり・個数・5区切り形式・コピー。専用プロセスで生成・再生成を実機確認。

- [ハッシュ・テストデータ生成](docs/DEVELOPER_GENERATORS.md)：4参照ツールを2入口へ統合。SHA／文章／文字列／CSV／UUID v4。全体テスト・ビルド・配置済み。既知SHA値と生成4モードを専用プロセスで実機確認。

- [サーバー・ネットワーク・日常計算11本](docs/SERVER_AND_EVERYDAY_TOOLS.md)：CIDR・DNS・単位・割合・電卓・数値集計とLinux系5本。参照元と再照合し、辞典162件＋補足3件・ツリー操作/JSON互換・入力形式などを補完。全体テスト・ビルド・配置済み。11本の代表入力・結果・主要操作を専用プロセスで実機確認。

- [ログハイライター](docs/LOG_HIGHLIGHTER.md)：ログレベル色分け・絞り込み・前後行・検索移動・カスタム強調・コピー。専用プロセスで解析・ERROR絞り込み・検索移動を実機確認。

- [JSONツール](docs/JSON_TOOLS.md)：共有入力の構造ビュー・整形・ビルダー。数値保持・JSON Pointer・型付き編集に対応。JSONのドロップ読込・UTF-8保存・未保存確認を追加。[ファイル検証](sessions/2026-10-15-51-json-files.md)。入力欄／本文への実ファイルdrop・通常編集・キャンセル保持を実機確認し、修正版を/Applicationsへ配置・起動済み。[記録](sessions/2026-10-15-42-json-workspace.md)。

- [正規表現・表・CSV統計の4ツール](docs/DATA_WORKBENCH.md)：テスター・条件ビルダー・Markdown/HTML/CSV出力・列別統計。最新版配置済み、4画面の代表入力・編集・コピー・エラー復帰を実機確認。表の3形式保存・CSV再読込も[確認済み](sessions/2026-10-15-50-table-file-roundtrip.md)。[記録](sessions/2026-10-15-48-data-tools-live.md)。

- [SQLツール](docs/SQL_TOOLS.md)：簡易整形・基本SELECTの定型説明・一時SQLite実行を3タブに統合。最新版へ配置し、サンプルの整形・説明・2行の実行結果を実機確認。

- [追加ツール一括検証](sessions/2026-10-15-49-batch-tool-validation.md)：単体140件・モデル23項目・Full成功、32画面×3テーマ描画。メモ／生成／検索を隔離環境で実操作。CIDRのCRLF行数とポート候補の番号表記を修正。

- [残る実機確認](sessions/2026-10-15-52-remaining-live-fixes.md)：メモJSON往復・表のWindows 98実表示／編集／コピー・SQL復帰を確認。ログの旧結果コピーとclassic ×の不動作を修正。

## 進行中
[IME・実sleep・8時間観測](sessions/2026-10-15-54-ime-sleep-soak.md)はユーザー依頼で中止。監視・検証用アプリと定期追跡を停止。[ロードマップ](docs/ROADMAP.md)・[可視化案](docs/VISUALIZATION_ROADMAP.md)は継続。

## 未実装
Battery温度・電力、内部SSD単独I/O、配布用署名／公証。

## 既知の問題・未確認
- M1 Max/32 GiB/P8 E2を確認。主要値は通常ユーザーで実測。定義と証拠は[技術検証](docs/TECHNICAL_VALIDATION.md)。
- .app起動・常駐、12ツール（16モード）の画面描画を確認。実機で刷新した一覧→営業日・1週間計算・画面目視を確認。CSVは表内/改行編集・保存・再読込・実ファイル一致、新3本と行/置換/リストの代表操作を実機確認。音声画面はAX確認。操作全体・音出し・マイク収録は未検証。
- sleep/wake・実IF切替・8時間以上の安定性・再ログイン起動・Parallels比較は未検証。
- RAM使用量とBattery容量は推定。GPU・トポロジー・Battery詳細の非公開キーはOS／機種依存。
## 技術的負債
Git管理済み（main、origin: https://github.com/maruyamamasaya/MyToolBox）。CI未整備。OS APIハングの強制timeoutなし。センサーの絶対精度・他機種互換性未検証、UI自動検証なし。

## 次に行うこと
未確認項目の再開順序・合否基準・停止済み試験は[引き継ぎチェックリスト](sessions/2026-10-15-56-resume-checklist.md)に集約。最新版メモの実機操作と/Applications反映が最初の残件。
[移行チェックリスト](docs/MIGRATION_CHECKLIST.md)のGUI・設定・sleep・IF切替を実機確認。温度の負荷追従・ファン回転中の観測、画像を参考にした可視化を進める。
