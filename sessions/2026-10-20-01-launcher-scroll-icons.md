# ツール一覧のスクロール時アイコン欠落対策

## Request / Investigation
ツール一覧のテキスト・CSVカテゴリで、スクロールすると時々アイコンが消えるとの報告。
ToolLauncherはカテゴリ別のLazyVGridを使用。実機での再現・原因確定は未実施。

## Changes / Files Changed
Sources/MyToolBox/UI/ToolLauncher.swiftのLazyVGridを全セルを保持するLayoutに変更。
6列のメニューと、ウィンドウ幅に合わせる可変列、セル寸法・お気に入り操作を維持。
55件の小規模カタログで遅延生成・破棄を避ける対策。

## Validation / Result
Fast成功。Fullは初回の署名証明書アクセス失敗後、通常署名環境で再実行し成功。
170単体テスト・Release build・署名・55helper検証成功。検証器8件成功。
実際のToolLauncherをsimple-darkでオフスクリーン描画し、テキスト・CSV全17アイコンを画像で確認。

## Remaining Issues
実機での反復スクロール・可変幅操作は未検証。間欠的な症状の解消は利用時に要確認。
本番未反映。本体・helperの終了／再起動・配置は行っていない。

## 後続
[一括配置](2026-10-20-04-icons-launcher-deploy.md)で可変一覧の起動時に無限大幅のInt変換クラッシュが判明。幅の正規化を追加し、4テーマ×3サイズ・実機起動／上下スクロールを確認して修正版へ配置済み。
