# インストール・ログイン起動・定期ログ

## Request / Investigation
Applications配置・自動起動・定点ログ。ユーザー選択は10秒ごと・7日間。AGENTS/CURRENT/OPERATIONS、App/Store/設定・Models・Preferencesと検証経路を確認。ユーザーの明示依頼が今回の配置・登録・ログ有効化の根拠。

## Changes / Files Changed
/Applications/MyToolBox.appに配置、明示保守コマンドからSMAppService登録。通常起動では登録しない。独立MonitoringLog actorで主要指標をUTC日別JSONL保存。設定UIからON/OFF・間隔・保持日数・エラー・保存先を表示。欠損状態、IF注記、セッションと時刻を保存。日別32MiB上限、期限終了した専用ファイルのみ整理。スリープ時停止、UI外で直列書込。
Core/Store/Settings/App、テスト、Xcode生成物、現在地・構造・配置・運用・検証文書を更新。

## Validation / Result
Fast/Full、25テストとビルドを実行。ログイン登録はraw status 1（enabled）を確認。更新後もstatus 1を確認。実ログが2→3行へ増加、最新間隔10.78秒、7カテゴリとstate/unit/reasonを確認。以前の配置版はbuild/installed-backups/20261015-114105/MyToolBox.appへ保存。実稼働は/Applications版。

## Remaining Issues
再ログイン実起動、長時間ログ稼働、実スリープ復帰は未検証。保持期間は日別単位のため最大1日余分に残る。CSV出力やログの長期間グラフUIは未実装。
