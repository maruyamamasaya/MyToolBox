# SQLツール

## Request / Investigation
指定Web版のSQL Formatter／Explainer／Playgroundを確認し、無理のない範囲でネイティブ実装。
HTML・JavaScript、既存ToolCatalog／ToolWindows／共通画面、SwiftPM・Xcode生成設定とテストを調査。

## Changes / Files Changed
- SQLText.swift：引用・コメントを保持する字句処理、簡易整形、単一基本SELECTの定型説明。
- SQLPlayground.swift：macOS標準SQLiteのメモリ内DB、専用actor、サンプル、全バッチのロールバック、実行／出力上限。
- SQLWorkspaceView.swift：共有入力の3タブ、結果・CSVコピー、テーブル構成、確認付き初期化。
- ToolCatalog／ToolWindows／ToolLauncherに登録。Package.swiftとプロジェクト生成にsqlite3リンクを追加。
- ビルド中に見つかったDirectoryTree／NetworkBuilder／ServerUtility画面の複数変数への@State指定を単一宣言へ分割。
- CURRENT／CODEMAP／ARCHITECTURE／TESTINGとSQL仕様書を更新。

## Validation
Fast成功。SQLToolsTestsの6件で引用・コメント・名前付きパラメーター、整形前後の実行結果、説明の対応範囲、JOIN／NULL、エラー／時間切れ時のロールバック、外部操作拒否、上限・復帰を確認。
Full成功：文書検証・Swift全単体テスト・Xcode Releaseビルド・.app実在・codesign検証。
git diff --check成功。検証器の負例5件成功。

## Result / Remaining Issues
SQL整形・説明・実行を「SQLツール」に統合。完全な方言対応・AI説明・実行計画・表直接編集・永続化は対象外。
実機UI操作・/Applicationsへの配置・今回分のコミット／プッシュは未実施。
