# OSによる本番アプリ更新経路の保護

## Request / Changes
別チャットの通常権限による直接コピーを防止する依頼。root所有・group/other書込み禁止・最上位.appのuchgで上書き／移動／削除を拒否し、root所有の固定更新処理に集約する実装を追加。
- scripts/protected_deploy.py：標準ライブラリのみ。管理者が初回導入し、専用コードと固定source／証明書署名要件をroot専用領域へ設置。常駐daemon・sudoers追加なし。
- root専用ステージへコピー後の署名照合、全helperのID／同一証明書／既存helper保持、停止再確認、交換後再保護、失敗時復旧と競合時バックアップ保持。リンク／特殊ファイル拒否。TCC・設定・アプリ起動終了は変更しない。
- scripts/deploy.py：保護済み本番は直接更新せず専用コマンドを案内して拒否。
- AGENTS／OPERATIONS／TESTINGとdocs/PROTECTED_DEPLOYMENT.mdに導入・更新・管理者による復旧を記録。

## Validation / Status
通常権限の回帰12件成功。Fast成功。Full成功（172単体・Releaseビルド・56helper署名）。
管理者認証が必要（sudo -n trueはpassword required）。この時点では導入前。後述の利用者認証により導入済み。
初回導入時、一時fixtureで元ユーザーに降格して書込み・作成・移動・uchg解除・chmodのOS拒否を確認し、失敗時は本番保護を適用しない。
管理者自身が明示認証してrootで迂回することまでは防げない。Fullや実キー確認の実施自体をOSで強制するものではない。

## 導入確認
利用者がターミナルでsudo認証してinstall実行。一時fixtureのwrite／create／rename／unlock／chmodが全てOSに拒否され、導入成功。
読み取り確認：本番の全内容がroot所有・group/other書込不可、最上位.appはuchg。専用領域／コード／policyはroot所有・通常ユーザー書込不可。導入済みコードと検証したソースのバイト一致を確認。アプリ再起動・TCC変更なし。
通常ユーザーuid 501で本番実行ファイルをO_WRONLY（切詰め・書込なし）で開く操作がOSに拒否された。従来deploy.pyも保護済みを検出してexit 1で専用コマンドを案内し、配置しないことを確認。
