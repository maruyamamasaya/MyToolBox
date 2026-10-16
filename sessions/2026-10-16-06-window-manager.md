# ウィンドウマネージャー

## Request
参考画像のようなウィンドウ配置ツールをMyToolBoxで使いたい。

## Investigation
AGENTS／CURRENT→CODEMAP／構成・運用・検証→ToolCatalog／ToolWindows／ToolLauncherと関連ロジック・テスト・生成設定を確認。semantic／IDE検索は未提供。既存のセキュリティ機能作業差分を保持。AppleのAccessibility API資料を参照。

## Changes / Files Changed
- WindowLayout：16配置、AX座標変換、端数境界を共有。
- WindowManagerModel/View：外部アプリ追跡、明示操作、権限案内、画面選択、復元、固定ホットキーON/OFF保存、失敗／サイズ制限表示。
- Catalog／ToolWindows／Launcherへ追加、プロジェクト再生成。
- WindowLayoutTests、RenderWindowManager、仕様・構成／運用／検証文書を更新。

## Validation
- Fast成功。Full成功（単体150件、Releaseビルド、署名）。test_verify.pyの5件成功。
- 3テーマをオフスクリーン描画、目視確認。描画専用コンパイルはBusinessDays／ToolFailure依存を追加して成功。
- CURRENTの行数制約超過を空行整理で修正後、Full成功。

## Result / Remaining Issues
ビルド成果物へ実装済み。/Applicationsへの配置は明示依頼がないため未実施。アクセシビリティ許可・外部ウィンドウの実操作・複数画面・ショートカット競合／再起動保持の実機確認は未実施。キー個別編集、ネイティブフルスクリーン切替は未対応。
