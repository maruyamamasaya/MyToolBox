# 本番アプリのOS保護

## 境界

本番 `/Applications/MyToolBox.app` と全内容をroot所有・通常ユーザー書込不可にし、最上位.appへuchg（移動・削除禁止）を付ける。所有者がrootのため通常ユーザーはuchgを解除できない。アプリの実行・設定保存先・TCC・署名は変えない。
専用更新処理と署名要件は `/Library/Application Support/MyToolBoxDeployment` のroot所有・書込不可ファイルへ固定する。常駐daemon・setuid・sudoers例外・パスワード不要の権限は作らない。管理者がsudoで実行する間だけ権限を使う。

同じユーザーで動く別チャットの通常コピー・上書き・移動はOSが拒否する。利用者が管理者認証して保護解除や別のrootコマンドを実行すれば迂回は可能。管理者自身を制限するものではない。物理キーの動作やFull検証の実施をOSだけで判定するものでもない。

## 初回導入

専用処理のソースは [protected_deploy.py](../scripts/protected_deploy.py)。初回だけ確認済みリポジトリから以下を利用者がターミナルで実行する。パスワードはsudoの入力欄にのみ入力する。

```sh
sudo /usr/bin/python3 -I /Users/maruyamasusumuya/Development/MyToolBox/scripts/protected_deploy.py install
```

導入処理は先に一時フォルダで元のユーザーへ権限を落とし、上書き・ファイル作成・移動・uchg解除・chmodがOSで拒否されることを検証する。失敗なら本番へ保護を適用しない。既存署名を確認し、専用コードと固定の更新元パス・署名要件をroot所有で保存してから本番を保護する。既存プログラムの無断上書き・再導入は拒否する。

## 以後の更新

[必須デプロイ手順](../OPERATIONS.md#デプロイの必須手順)のFull検証・保存確認・全ツール通常終了を行う。OS保護後に `scripts/deploy.py` を呼ぶと専用コマンドを案内して停止する。以下のroot所有コピーを使用する。

```sh
sudo /usr/bin/python3 -I '/Library/Application Support/MyToolBoxDeployment/protected_deploy.py' check
sudo /usr/bin/python3 -I '/Library/Application Support/MyToolBoxDeployment/protected_deploy.py' apply
```

更新元は導入時のリポジトリの `build/Build/Products/Release/MyToolBox.app` に固定。任意の配置先・フック・シェルコードは受け付けない。root専用の一時領域へコピー後、リンク／特殊ファイルを拒否し、固定した署名要件と全helperを検証する。新helperも同じ証明書・ID規則を必須とし、既存helperの欠落は拒否する。停止を再確認した後だけ交換し、root所有・uchgを再適用する。検証失敗時は復旧し、起動競合時は旧版を保持する。

成功後に通常ユーザーで本体を起動し、外部アプリの配置／復元を実キーで確認する。更新処理はアプリの起動終了・TCC変更を行わない。リポジトリ側の検証ビルド出力は配置確認後に通常ユーザーで整理する。専用コードを変更する場合も管理者によるレビュー・明示的な保守が必要。

## 状態確認・復旧

```sh
sudo /usr/bin/python3 -I '/Library/Application Support/MyToolBoxDeployment/protected_deploy.py' status
```

復旧のため利用者が明示依頼した場合に限り、全ツール停止後に以下を実行する。uchgを解除し、導入前のユーザー所有へ戻す。アプリや設定は削除しない。root所有の専用コードとpolicyは監査用に保持する。

```sh
sudo /usr/bin/python3 -I '/Library/Application Support/MyToolBoxDeployment/protected_deploy.py' remove-protection
```

更新失敗時に表示された `transaction-*` は復旧まで削除しない。管理者認証ができない場合、保護の導入・更新・解除は未完了として扱う。
