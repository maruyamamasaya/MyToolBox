# 本体アイコンの白枠廃止

## Request / Investigation
本体アプリのアイコン差替え、白い枠をなくす依頼。既存素材・build_icon.py・bundle参照・開発手順・検証方法を確認。

## Changes / Files Changed
imagegenで背景台座のない青い工具箱とシアンの波形を生成。Resources/AppIcon/source.pngとMyToolBox.icnsを差替え、同READMEに出自とプロンプトを保存。CURRENTへ開発版であることを記録し、既存の行数超過を空行整理で解消。個別ツールのアイコンは変更なし。

## Validation / Result
Fast成功、test_verify.pyの8件成功。64px素材の目視で形と波形を確認。1254px正方形・alphaあり、sips/iconutilで16〜1024pxを生成。sandbox内iconutil失敗は通常権限で再実行して成功。Fullはsandbox内で署名証明書が見つからず失敗し、通常権限で再実行しFull成功（単体・Releaseビルド・署名・56helper検証）。

## Remaining Issues
利用者の本番反映依頼後、本体・windowManagerのみ起動中であることを確認し、両方を通常終了。deploy.pyでOS保護を検出し、利用者がTerminalで管理者認証してroot所有の専用check→applyを実行。更新・署名・保護・旧版整理の成功と新版2プロセス起動を確認。346ファイル全一致後、固定ビルド.appを削除。配置後の再実行は起動中検出で拒否され、追加更新なし。

配置／復元ボタンの実行結果を実画面で確認。実キーによる配置・復元も利用者が成功を確認。Dock／Finderのアイコンキャッシュ目視は未確認。
