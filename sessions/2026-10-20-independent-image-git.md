# 画像リサイズ・Git一括管理の独立プロセス

## Request
2ツールを別プロセスへ追加し、本体再起動中も作業を継続する構成へ変更。実装とバックグラウンド検証まで。本番配置・本番アプリ操作なし。

## Investigation
IndependentTools → ToolWindows.show → helper側AppDelegateの既存経路を利用。画像はモデル内の入力・設定・プレビュー・一括結果とTaskを保持。Gitはactor実行中のbusyで終了を拒否。Gitのroot保存が.standardだったため、helperからも既存設定へ接続する必要あり。

## Changes
- imageResizer／gitBatchを固有bundle IDの同梱helperへ追加（計11本）。本体の終了処理で対象モデルやTaskを停止しない。
- GitBatchModelのUserDefaultsを注入可能にして既存local.MyToolBoxを共有。実際の終了制御で使うcanCloseと、テスト用の確認判断境界を追加。既定の確認ダイアログを維持。
- 画像モデルのsave(to:)／resizeBatch(in:)をパネル選択部分から分け、同じ処理を合成画像・隔離保存先で検証できるようにした。画像自身のcloseで中断する仕様は維持。
- Fullと検証器の欠落負例を11helperへ拡張。

## Validation
- Fast → Full成功（Swift単体・Releaseビルド・11helperのID／実行ファイル・deep署名）。Python検証器7件、Python構文、git diff --check成功。
- VerifyIndependentImageGit：ルート／実モデル28項目成功。合成PNG→JPEGの寸法・品質設定／保存／元画像保護、3入力の一括処理で不正画像の後も継続・保存済み2件／失敗1件の結果保持と原本不変を確認。
- Gitは隔離bare origin・2cloneだけで実行。root設定引継ぎ、読込／処理中の終了拒否と重複実行拒否、確認キャンセル、入力メッセージを文字列のままコミット、ローカルpush、先行検出・ff更新、失敗後のbusy解除と保存root保持を確認。ユーザーrepo／外部サービスへの送信なし。
- 4テーマ×単一画像／一括画像／Gitの12画面を非表示描画。simple-darkの単一画像とGit画像を目視確認。NSAppはprohibited、AppStorageは隔離、パネル／実キー／クリップボード／本番アプリ操作なし。
- 当初のGit選択チェックは同じ一時ディレクトリの/varと/private/var表記差で失敗。両方を解決したパスと一覧の選択整合で比較するようテストを修正し、全40項目成功を再確認。必要な実ソース17ファイルを一時コピーしてコンパイル。

## Result
実装とバックグラウンド検証完了。本番未反映。build/Build/Products/Release/MyToolBox.appを一括デプロイ用の開発成果物として保持。

## Remaining Issues
ユーザー指定により本体実再起動・実画面再表示・ファイルパネル／dropは未実施。実サービスへのGit fetch／push・認証は未確認。ツール自身の終了やMac再起動・クラッシュ後の全作業復元は今回の範囲外。

## 後続の反映
2026-10-20に[一括デプロイ](2026-10-20-combined-deploy.md)済み。起動中の独立ツールは作業保護のため再起動せず、次回起動から新版を使用。上記検証・未確認事項は実施時点の記録。
