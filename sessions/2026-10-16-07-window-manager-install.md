# ウィンドウマネージャー最新版の配置

## Request
最新版を/Applicationsへ反映し、使えるようにする。

## Investigation / Changes
AGENTS／CURRENT／OPERATIONSの配置・最新版保持ルール、TESTING、アプリの正常終了・ログイン確認経路を確認。実装変更なし。

## Validation / Result
- 前の作業で単体150件・Full・署名成功。本作業でもFast成功。
- Release成果物を検証し、ステージへコピー、署名・全ファイルSHA-256一致確認。
- 既存アプリを正常終了し、/Applications/MyToolBox.appを更新・起動。
- 配置先の署名・全ファイル一致、起動プロセスの実パス（PID 35129）、loginStatus=1を確認。
- 成功後、一時旧版.appを削除。設定・ログは保持。
- 実際の一覧で51件、検索→ウィンドウマネージャー起動をComputer Useで確認。
- アクセシビリティは未許可。16配置ボタンが無効、許可案内と設定ボタン、ショートカットOFFを確認。

## Remaining Issues
ユーザーがシステム設定からMyToolBoxのアクセシビリティを許可し、画面の「許可を再確認」を押す必要がある。権限を自動変更していない。外部ウィンドウ操作の実機検証は未実施。
