# ツール一覧とシステムモニター

## Request / Investigation
既存メニューバーを残してツール一覧を作り、システムモニターをその1つとして配置。AGENTS/CURRENT、構造・検索入口・検証、AppDelegate/Dashboard/Store/設定と起動経路を確認。semanticツールなし。

## Changes / Files Changed
ToolCatalogとToolLauncherを追加。専用四角グリッドアイコン→一覧→モニター、数値メニュー→モニター直行、モニター下端→一覧の導線。単一popoverと同一Storeを共有、監視・ログを複製しない。Finderから再度開くと一覧。未実装ツールは掲載しない。
App/UI、Xcode生成物、描画ツール、README/現在地/構造/運用/検証/検索入口を更新。全体ロードマップとADR0005を追加。

## Validation / Result
Fast/Full（25テスト、Xcode、署名・.app）、一覧とモニターのオフスクリーン描画で検証。配置済みアプリを更新。ログインstatus 1、実ログ追記（最新間隔10.64秒）、/Applications版の単一プロセスを確認。旧版はbuild/installed-backups/20261015-123240/MyToolBox.appに保存。

## Remaining Issues
実デスクトップのツール一覧開閉・導線・ノッチ干渉は未検証。追加ツールは今後個別に選定。検索・分類・お気に入りは未実装。
