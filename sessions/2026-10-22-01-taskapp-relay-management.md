# TaskApp中継のサーバー管理追加

- Request：既にLaunchAgent化されたCalendarTaskAppのDot／iPhone中継をサーバー管理へ追加。
- Investigation：既存は読み取り専用。TaskAppのSERVICE-PROPOSAL.mdと照合し、固定のユーザーLaunchAgentと承認済みLAN待受を対象にした。
- Changes：独立したTaskAppカード、TCP 8778のPython／192.168.0.35限定判定、launchctl blameの診断応答、確認日時と運用上の制約を追加。後続依頼でメニューにもTaskAppを追加、写真／音楽を左列上下・TaskAppを右列上に置く2列×2段。タスクアイコンと状態点、確認時刻を表示。
- Files Changed：ServerManagement.swift、ServerManagementView.swift、ServerManagementTests.swift、RenderServerManagement.swift、docs/SERVER_MANAGEMENT.md、CODEMAP.md、CURRENT.md。
- Validation：Fastと179単体成功、検証器8件成功。4テーマ×7状態×2幅の56画面を非表示描画、Blue Cosmos 800幅を目視確認。実コレクターでTaskAppのLAN待受／常駐診断を確認済み。写真health・Tailscale／Serveは実行環境で取得不可、成功扱いしない。
- Full：最初の制限環境では署名証明書が見つからず失敗。既存キーチェーンへのアクセスを伴う再実行でFull成功（Release・署名・56helper）。
- Result：開発版への追加。本番配置・本体再起動・サービス停止／再起動・登録変更なし。設定・タスク・認証・証明書・ログの読取りなし。
- メニュー追加検証：明暗×7状態の14描画、実コレクターで3項目の選択とTaskApp待受を確認。Fast・179単体・Full（Release／署名／56helper）を再実行し成功。本番反映は管理者認証待ち。
- Remaining Issues：実画面のスクロール／更新操作、TLS・端末認証・iPhone接続・常駐PID一致、再ログイン・sleep復帰は未検証。別件の作業ツリー変更は保持。

## 本番反映後の確認
- 利用者が専用root更新処理を実行したと申告。配置先346ファイルのSHA256が最新ビルドと全一致、deep署名成功、root所有・uchgを確認。
- /Applicationsから本体を起動。新版サーバー管理のTaskApp待受／常駐応答・確認時刻更新・スクロールを実UI確認。
- ウィンドウ配置の許可済み／キーONを確認。Finderのボタン中央配置と復元の成功表示を確認。左半分・最大化は指定位置との不一致を報告したため成功扱いしない。自動キー入力も成功判定できず、物理キー確認は利用者へ依頼。
- メニューバーはネイティブUI取得がウィンドウ範囲に限られ、2列3項目の実表示・クリックは未確認。新版コードと描画プローブでは検証済み。
- 全一致確認後、固定パスの検証用.appを削除。本番1本のみ保持。TaskApp中継サービスの停止・設定変更は実施せず。
