# サーバー管理の読取専用画面

## Request
同じ Mac で動く写真サーバーを MyToolBox のツール一覧から確認する。配置・サービス操作・VPN変更は行わない。

## Investigation
baby-media-web の CURRENT、iOS Info.plist、運用・起動処理から「凛紬花ちゃん」との共有サーバー関係を確認。実機で固定 LaunchDaemon、Node.js の TCP 8080 待受、ローカル health の HTTP 200、Tailscale の接続、Serve 443 → 8080、Funnel 無効を確認した。

## Changes
「ネットワーク・サーバー」に「サーバー管理」を追加。表示時と手動操作で1回取得し、各結果・最終確認日時を表示。非同期 actor・重複防止・最大5秒／コマンド。HTTP は3秒、本文破棄、ユーザーcurl設定・プロキシ・リダイレクトなし。取得失敗を停止と断定しない。launchd は環境変数を取得しない blame の診断応答を参考情報とする。生出力・端末識別情報は表示しない。[仕様](../docs/SERVER_MANAGEMENT.md)。

## Files Changed
新規：ServerManagement.swift、ServerManagementView.swift、ServerManagementTests.swift、docs/SERVER_MANAGEMENT.md、本記録。
連携：Security.swift の限定環境変数追加引数、ToolCatalog.swift、ToolWindows.swift、ToolLauncher.swift、Xcode 構成。現在地・構造・CODEMAP を追記。既存の未コミット変更は保持。

## Validation
- Fast 成功。追加6件を含む全163単体テスト成功。
- 最終 Full 成功：文書、全単体、Release build、codesign。検証器の6テスト成功。git diff --check 成功。
- 同じ実装のコレクターを2回実行し、全5項目を約0.22秒／0.23秒で確認。
- 独立した描画プロセスで Blue Cosmos／Living Aurora／Windows 98 の3テーマを生成し目視確認。通常アプリの置換・起動は行っていない。
- 初回 Full は CURRENT の80行制限で失敗し、空行1行を削除して再実行成功。初回描画用ビルドは入力ファイル編集中の検出で失敗し、最終ソースを用いた再ビルド成功。

## Result
ローカル実装・ビルド・検証まで完了。既存の /Applications アプリ、写真・認証情報・VPN／権限／常駐設定は変更していない。再起動・停止・インストール・pushなし。

## Remaining Issues
実際の一覧クリック・手動更新ボタン・小さいウィンドウでのスクロールは未確認。launchctl blame は診断用参考情報で、8080 の PID と固定サービスの PID の一致は未検証。別 Mac、外出先 VPN、ログイン、画像閲覧の検証は対象外。
