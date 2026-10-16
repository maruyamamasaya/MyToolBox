# アクセシビリティ登録の初期化

## Request / Investigation
システム設定で許可できないとの報告。実画面でMyToolBoxの設定ONとアプリ側の未許可を確認。再確認・正常終了／再起動でも一致しない。署名は証明書方式を維持。

## Changes / Result
ユーザーの明示承認後、`tccutil reset Accessibility local.MyToolBox`を実行して成功。設定画面からMyToolBoxの旧行が消えたことを確認。他アプリの許可を変更していない。

追加のファイル選択画面で `/Applications/MyToolBox.app` を選択し、「開く」が有効になったところまで準備。最後の登録・許可と認証はユーザーへ引き継ぐ。アプリ実装・署名・ビルドの変更はなし。

## Remaining Issues
現在の署名に対する許可と、再起動後の維持は未確認。
