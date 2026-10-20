# Dockとツール一覧ウィンドウ

- メニューバー常駐を維持し、本体をregular activation／LSUIElement=falseに変更。
- 通常起動・Dock／Finder再オープン・アプリメニュー⌘1・メニュー一覧下端から同じ通常ウィンドウを開く。ログイン起動イベントでは自動表示しない。
- 既存ToolLauncherとToolWindowを共用。検索状態は保持したウィンドウで継続、お気に入り・テーマは共通設定。監視Storeを追加生成しない。
- ×後も常駐を継続。最小化後は復帰。通常の終了は従来の確認経由。
- 検証：Fast・Full成功、単体167件・検証器7件成功。Releaseビルド・既存証明書署名確認成功、生成Info.plistのLSUIElement=falseを確認。
- 実ToolLauncherを4テーマでオフスクリーン描画、Blue Cosmos／Windows 98の導線と配置を確認（画像は/tmp/mytoolbox-dock-*.png）。この時点では実デスクトップのDock操作・最小化復帰・ログイン起動は未検証。
- 最初のFullはsandbox内で証明書を参照できず失敗。権限を広げた再実行で成功。
- ユーザー依頼で/Applicationsへ反映・起動済み。独立ツールの稼働なしを確認し、本体をメニューの確認付き終了から停止して配置。
- 新旧designated requirement一致、配置前後の全ファイルSHA-256一致、deep/strict署名検証成功。成功後に旧版バックアップとbuild側.appを削除。
- 本番の標準ウィンドウ「MyToolBox — ツール一覧」と55件・既存お気に入りをAX／画面で確認。
- Dock取得はComputer Useでtimeoutが反復。この時点ではDock直接クリックの検証は未完了。キーボード経由もDock選択を確認できず成功扱いにしていない。検索欄への試験入力は解除済み。
- ログイン起動・最小化復帰は引き続き未検証。

## Dock再確認
- ユーザー依頼で別方式のAppleScript/System EventsによるDock項目読取を試行。osascriptの補助アクセス拒否（-1719）で操作不能。権限設定は変更していない。
- Computer Useの再オープン・閉じる試験もメニュー状態が更新されず、Dockクリックの成功証拠は得られなかった。この時点ではDock直接操作は未確認。

## ユーザー実機確認（2026-10-20・日本時間）
- ユーザーから「Dockからツール一覧を開けた」と報告あり。本番アプリでDockから通常のツール一覧を開く操作は確認済み。
- 確認者はユーザー。先行する自動操作のtimeout／補助アクセス拒否とは区別する。ログイン起動・最小化復帰は引き続き未検証。

## 最小化からのDock復帰試験
- 本番一覧のminimize buttonをComputer Useから操作したが、続くAX観測では変化がなく、最小化状態の成立は確認できなかった。
- Dock.appへの接続もtimeoutReached。最小化後のDock復帰は未検証のまま。実装のdeminiaturize呼出しだけを実機成功の証拠にはしていない。
