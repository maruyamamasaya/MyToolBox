# 独立ツールのアイコン

独立ツールは青い角丸タイルと用途ごとの立体的な絵柄で統一する。本体の工具箱アイコンはResources/MyToolBox.icns。

## 新しいツールを追加するとき

ツールの実装と専用アイコンを一緒に追加する（ユーザー指定、2026-10-20）。
画像生成スキルで既存の青い統一デザインに合わせ、用途の分かる絵柄を作る。
ToolIDに対応する元PNG・生成指示・ICNSを保存し、helperへ組み込む。
96px／32pxの一覧描画とFull検証で表示・素材一致・署名を確認して開発完了とする。本番反映は別途一括実施。

## 素材と再生成

- 元画像：Resources/ToolIcons/sources/<ToolID>.png。組込みの画像生成ツールで作成、タイルの外側は透過。
- 生成指示：Resources/ToolIcons/prompts.json。baseと各subjectsを連結。試作4点はprototypesに記録。
- 配布素材：Resources/ToolIcons/<ToolID>.icns。16〜1024pxの10サイズを同梱。
- 変換：`python3 scripts/build_tool_icons.py`。外部通信なし。生成画像の作成自体はこのスクリプトには含まない。

## 梱包と検証

scripts/embed_tool_apps.pyが各helperのResources/ToolIcon.icnsへ対応する素材をコピーし、Info.plistのCFBundleIconFileへ設定する。
以前のビルドに残る共通MyToolBox.icnsはhelperから除去する。
通常のFull検証は全helperのアイコン設定・存在・元ICNSとのバイト一致とdeep署名を確認する。
検証器の負例はアイコン欠落・誤画像を拒否する。

一覧画像は次のバックグラウンド描画で生成する。画面表示・起動・設定変更は行わない。

```sh
xcrun swiftc -module-cache-path .build/clang-cache -parse-as-library Sources/MyToolBox/App/ToolCatalog.swift tools/RenderToolIcons.swift -o build/render-tool-icons
build/render-tool-icons
build/render-tool-icons --small
```

出力：evidence/tool-icons/all-tools.png（96px）・small-tools.png（32px）。これは素材の描画確認であり、DockやFinderのキャッシュ更新・実機表示の確認とは区別する。
本番反映は[開発時の注意点](DEVELOPMENT_WORKFLOW.md)に従い、一括デプロイ時に実施する。
