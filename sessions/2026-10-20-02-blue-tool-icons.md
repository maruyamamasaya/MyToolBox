# 青い専用ツールアイコン

## Request / Investigation
画像生成による4試作を確認後、青いデザインで独立ツール全体を揃える依頼。
既存梱包は全55helperに本体の共通ICNSをコピーしていた。

## Changes / Files Changed
- Resources/ToolIcons/sourcesに55種の生成PNG、同フォルダ上位に55種のICNSを保存。
- 組込み画像生成ツールを使用。青い角丸・立体的な道具・タイル外側透過で統一。
- 生成指示はResources/ToolIcons/prompts.json。試作4点はprototypeBase＋prototypes、追加51点はbase＋subjects。
- scripts/build_tool_icons.pyで16〜1024pxの10サイズへ変換。
- scripts/embed_tool_apps.pyで対応画像をhelperのToolIcon.icnsへコピーし、Info.plistを設定。旧共通アイコンを除去。
- scripts/app_verify.pyで全素材一致、scripts/test_verify.pyで欠落・誤画像拒否を検証。
- tools/RenderToolIcons.swiftで実ICNSの96px／32px一覧を非表示描画。
- docs/TOOL_ICONS.md・CODEMAP・TESTING・CURRENTへ配置と検証方法を記録。

## Validation / Result
- Fast成功、170単体・Full Release build・deep署名・55helper素材一致成功。
- Python検証器8件成功。55 PNGは異なる内容・正方形・1024px以上・alphaあり。
- 55 ICNSは異なる内容・有効なコンテナ・10サイズを確認。
- evidence/tool-icons/all-tools.png・small-tools.pngを目視し全55種の表示を確認。
- iconutilは制限環境でInvalid Iconsetとなり、通常環境で再実行して成功。
- git diff --check、変更Pythonの構文確認成功。

## Remaining Issues
本番未反映。Dock／Finder実機表示・アイコンキャッシュ更新は未検証。
利用中の本体・helperの終了／再起動や配置は行っていない。

## 後続
ユーザーの明示依頼により[一覧修正と一括配置済み](2026-10-20-04-icons-launcher-deploy.md)。本体とウィンドウ配置を新版へ再起動し、55素材一致と設定維持を確認。
