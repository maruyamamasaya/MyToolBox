# 追加分のアプリ反映

## Request / Investigation
追加済みの機能をアプリへ反映して利用可能にする依頼。最新版保持ルール、起動中のアプリと検証手順を確認。

## Changes / Files Changed
最新版Releaseを/Applications/MyToolBox.appへ配置し通常再起動。
CURRENTの検証・配置状態とOPERATIONSのツール数・リモート記載を更新。
最終チェックで追加された境界テストが検出したCIDRのCRLF二重計数を、改行正規化の1行修正で解消。再Full成功後、修正版を再配置・再起動して実行ファイル一致を確認。

## Validation
Fast／Full成功（文書、Swift単体137件、Releaseビルド、.app・署名検証）。検証器の負例5件成功。
インストール版とビルド版の実行ファイルSHA-256一致。/Applicationsの実プロセスを確認。loginStatus=1（enabled）。
実機一覧49件、SQL画面のサンプル整形・説明・SQLiteの2行の集計結果を確認。
正規表現テスターのサンプル一致2件とキャプチャ置換結果を確認。
表ビルダーのサンプル表示、行追加による4行化とMarkdown出力更新を確認。

## Result / Remaining Issues
固定パスで最新版が起動。配置・起動・署名確認の成功後に一時退避した旧版.appのみを削除し、最新版だけを保持。
設定・ログ・保存済みユーザーデータは維持。全ツール全操作・全テーマの実機確認、長時間試験は未実施。
追加依頼により、今回の修正・単体テスト・検証用ツール・更新記録をまとめてコミットし、origin/mainへプッシュ。送信後にローカルとリモート追跡参照の一致を確認する。
追加のtools/VerifyAddedTools.swiftは今回のコミット作業では実行していない。
