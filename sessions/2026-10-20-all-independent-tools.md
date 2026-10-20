# 残る43ツールの独立プロセス化

## Request
全55ツールを別プロセス化。選択したものだけ起動し、常駐が必要なもの以外は閉じたら終了。デプロイせず実装とバックグラウンド検証まで。

## Investigation
12 helperは既存の共有実行ファイル方式。残る43本もToolWindowsに実装済みだが、systemMonitorだけはAppDelegateが本体画面へ分岐していた。日程計算のBundle内祝日、ディレクトリツリーの.standard、マイクの用途文／音声入力entitlement、本体とモニターのログ・ログイン所有が分離時の依存。

## Changes
- IndependentToolsを全ToolIDへ拡張。梱包／検証はSwiftカタログを読み、55 helperの対象・名前を一致させる。
- 一覧のモニターも独立helperへ配送。本体のメニュー監視と管理設定は維持。独立モニターはログ保存・ログイン登録を行わず、表示設定は既存ドメインを共有・再読込。
- 通常closeは既存のcanClose／cleanup後にhelper終了、windowManagerのON時だけ常駐。helperは他ToolIDを同一プロセス内で開かない。音声停止のsleep監視をhelperにも適用。
- 日程調整へ祝日を同梱、ツリーの既存保存ドメインを継承。マイクhelperへ用途文・audio-input entitlementを付与し、Fullで確認。
- 起動・表示・終了の境界をToolWindowsへ注入可能にし、バックグラウンドで本番経路とclose guardを検証。

## Files Changed
IndependentTools／ToolWindows／AppDelegate／MonitorStore／Dashboard／SettingsPanel／DirectoryTreeView、scriptsのtool_catalog／embed_tool_apps／app_verify／test_verify、VerifyAllIndependentTools、関連設計・運用文書。

## Validation
- Fast / Full成功。Swift単体170件、Xcode Releaseビルド、全55helperのID／実行ファイル／祝日／マイク用途文・音声入力entitlement／deep署名を確認。
- VerifyAllIndependentTools: 132項目＋4テーマ×2画面の非表示描画8項目（計140 PASS）。全55配送・全55常駐条件、実ToolWindowの拒否／許可／cleanup／終了、親側の非所有、ツリー保存、モニター管理権限・共有設定を隔離検証。
- 既存ショートカット回帰11項目、Python検証器8件、Python構文、文書検証、git diff --check成功。
- 初回Fullは外側Info.plist生成前の参照で失敗。用途文を元Resources/Info.plistから取得する形へ修正し、同条件の梱包テストを追加。再Full成功。
- 証跡は`build/validation/all-independent-tools/`、描画は`build/all-independent-preview/`。モニターは自動取得を停止した未計測表示を描画し、実測成功とは扱わない。

## Result
全55ツールの独立化とバックグラウンド検証を完了。本番未反映。起動したhelper内の作業状態は本体の終了から独立する。通常closeで終了、ショートカットONのwindowManagerだけ常駐。

## Remaining Issues
実LaunchServices起動・本体実再起動中のPID維持・55画面の実操作・マイク許可と音声・AX許可・物理キーは未実施。マイクとショートカット競合チェックの独立IDには、デプロイ後にOS許可確認が必要になり得る。実機操作とデプロイは実行しない。

## 後続の反映
2026-10-20に[一括デプロイ](2026-10-20-combined-deploy.md)済み。起動中の独立ツールは作業保護のため再起動せず、次回起動から新版を使用。上記検証・未確認事項は実施時点の記録。
