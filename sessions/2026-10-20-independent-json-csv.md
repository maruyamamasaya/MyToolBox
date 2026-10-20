# JSON・CSVツールの独立プロセス

## Request
JSONツールとCSVビューワー／エディターを別プロセスへ追加し、本体再起動で編集内容を失わない構成にする。実装とバックグラウンド検証まで。本番配置・本番アプリ操作なし。

## Investigation
ToolWindows.showの独立起動分岐、JSONWorkspaceModel／CSVModelの状態・ファイル処理・終了確認、共通helper構成と検証器を確認。JSON／CSVともwindow内のモデルが入力・選択・解析結果を保持し、主アプリに状態の正本を置かない構成を再利用する。

## Changes
- jsonWorkspace・csvViewer・csvEditorを各固有bundle IDのhelperへ追加。CSVの閲覧と編集も別プロセスとし、一覧の入口は維持。
- JSON／CSVの未保存終了確認へ判断処理を注入可能にし、テスト時はダイアログを出さず同じ判定を確認。既定の実UI確認は維持。
- CSVは読込／解析中の終了を拒否。パネルを介さないsave(to:)を既存保存処理から分け、実モデルの保存成功・失敗を隔離ファイルで検証可能にした。
- helper9本のID・実行ファイル・署名をFull対象に追加。新3本の欠落を検証器の負例で確認。

## Validation
- Fast → Full成功（Swift単体・Releaseビルド・9helperのID／実行ファイル・deep署名）。Python検証器7件・構文検証・git diff --check成功。
- VerifyIndependentDocumentsのルート／モデル24項目成功。JSONの数値・Unicode・ツリー選択、未完成入力の保護、保存基準／ファイル関連付け保持、CSVの閲覧書込禁止・未解析入力・検索／ソート／選択の保持、引用／改行の保存再読込、保存先エラー時のドラフト保持を確認。
- 同プローブで4テーマ×3ツールの12画面をオフスクリーン描画。simple-darkのJSON・CSV編集画像を目視確認。意図した保存失敗の表示と未保存マークも保持。
- NSAppはprohibited、AppStorageとファイルはUUID付きの隔離先。未保存判断だけを注入し、ファイルパネル・クリップボード・実キー・本番アプリを操作しない。必要な実ソース20ファイルを一時コピーして固定しコンパイル。
- プローブ実行時にhiservices XPCのConnection invalidログが出たが、終了コード0、全36項目と生成画像の確認は成功。実キー／フォーカス成功の証拠にはしない。

## Result
実装とバックグラウンド検証完了。本番未反映。build/Build/Products/Release/MyToolBox.appは一括デプロイ用の開発成果物として保持。

## Remaining Issues
ユーザー指定により、本体の実終了／再起動、実キー操作、IME編集中・native表セルのフォーカス確定、ファイルパネルは実機未確認。ツール自身の終了・Mac再起動・クラッシュ後に全ドラフトを自動復元する機能は追加しない。

## 後続の反映
2026-10-20に[一括デプロイ](2026-10-20-combined-deploy.md)済み。起動中の独立ツールは作業保護のため再起動せず、次回起動から新版を使用。上記検証・未確認事項は実施時点の記録。
