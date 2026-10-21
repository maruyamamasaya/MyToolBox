# デプロイ後のウィンドウ配置停止の調査と防止

## Request / Investigation
更新後に繰り返し配置不能。ユーザー確認：許可ON、OFF→ONで登録成功、キーとボタンとも配置不能。
旧helper PID 65602は10/20 18:04から常駐。10/21 01:55の配置でPID維持・旧版削除の記録あり。09:38のsampleはイベント待ちでハングを示さなかった。
TCCの09:39ログは同PIDに `proc_pidpath_audittoken() failed ... No such file or directory` を記録。設定ONやCarbon登録成功とは別に、旧プロセスの実行パス解決が壊れていたことを確認。後の読取時にはPID 39062へ切替済み。本チャットから終了・起動・TCC変更はしていない。新PIDでの物理操作復旧は未確認。

## Changes / Files Changed
- scripts/deploy.py：既定は事前検査のみ。全本体／helperの停止必須、全素材・deep署名・既存56アプリの署名要件を新コードで評価。明示--applyでステージ配置・直前再検査・配置後検証・失敗時復旧／バックアップ保持・成功時整理。
- scripts/test_deploy.py：実プロセス・配置を操作しない8回帰テスト。app_verify.pyからFast／Fullに組込み。
- OPERATIONS.md：起動中helperを残してバンドル交換・旧版削除する運用を廃止。停止→検査→配置→通常起動→実キー確認を必須化。
- TESTING.md／docs/WINDOW_MANAGER.md：検証と更新方法へリンク。

## Validation / Result / Remaining Issues
回帰8件、Fast、検証器8件成功。Full再実行成功（単体171件・Releaseビルド・署名・55helper資源）。初回Fullはsandbox内で既存証明書参照失敗、署名設定を変えず通常権限で再実行。
実環境の読取専用preflightは本体12964・ポモドーロ29034・配置39062を検出し、変更前にexit 1で拒否（期待通り）。
本番未反映。許可リセット・署名変更・強制終了なし。デプロイをまたぐ実キー／AX復旧は未検証。手動コピーで専用検査を迂回する更新は禁止。配置中の起動競合は再検査で検出するが、OSのアプリ起動自体をロックするものではない。
