# 一括検証後の修正をインストール版へ反映

- ユーザーの依頼により、修正済みReleaseを`/Applications/MyToolBox.app`へ反映。
- 更新前にFull成功：単体138件・文書・Xcode Releaseビルド・codesign。ログは`build/validation/install-latest-full.log`。
- アプリメニューの終了確認で通常終了。起動中チェック後に新版を一時配置・署名検証し、旧版を一時退避して固定パスへ入替。
- 更新後にComputer Useで49ツールの一覧表示を確認。インストール先から動く単一プロセスを確認。
- ビルド版とインストール版の全通常ファイルのSHA-256マニフェスト一致、署名成功。
- 実行ファイルSHA-256：`c1d810f2ba75a6452a9c7f88db946fed0ad4c554b60cdf0a8ebc6ff8332a4828`。
- `--login-status`は`loginStatus=1`（enabled）。ログイン登録の変更は実施しない。
- 成功後、今回の`.MyToolBox-update-backup.app`を削除し、stage／backupが残っていないことを確認。
- 設定・ユーザーメモ・ログを変更しない。Gitコミット／プッシュはこの作業では行わない。
