# 残る実機確認と修正

## 検証環境
通常のMyToolBoxとは別ID・専用UserDefaults・一時メモのネイティブ検証アプリで操作。ManualToolCheckへ標準Editメニューを追加し、コピー／貼り付け／全選択を実際のレスポンダーチェーンで検証。表・JSON・SQLの入口も追加。

## 実操作で確認したこと
- メモ：日本語・絵文字・カンマ・二重引用符・改行を含む本文をJSON保存。実ファイルを解析し本文／タイトルの一致を確認。別内容へ編集後、標準Openパネルで保存JSONを選択→確認→復元し元本文へ戻ることを確認。
- メモ：保存パネルのキャンセル後の保持、Blue Cosmos→Windows 98→Living Auroraの即時切替でタイトル／本文の保持。Windows 98の白い本文欄と操作ボタンを実スクリーンで目視。
- 表：Windows 98のAppKit表は実画面で白背景・文字・列見出しを正常表示。以前の黒い合成画像とは異なる。セルをダブルクリック→全選択→12へ変更→Enterで出力にも12を反映。
- 表：Markdownをコピーし、取り込み欄へキーボードで貼り付け。ヘッダー・改行・日本語・編集後の12を含む文字列が出力と一致。
- SQL：Windows 98でSELECT 1の結果をCSVコピー→入力欄へ貼付し`value`／`1`と一致。入力変更で前結果を消しコピー無効。存在しない表のエラー後、SELECT 2で復帰。DB初期化のキャンセルで結果2を保持。

## 見つかった不具合と修正
1. ログの解析後に入力を書き換えても、古い解析結果が残りコピー可能。2,000,001バイトの容量超過後も同じ状態を再現。入力変更時に結果・検索位置を破棄し、再解析の案内を表示するよう修正。修正版で変更後の全0行・コピー無効、容量超過エラー・旧結果なしを実機再確認。
2. Windows 98の×が反応しない。borderless windowに対するperformCloseが動作しないため、delegateのwindowShouldCloseを通してから直接closeするThemeWindowActionsを追加。修正版の×をクリックして表画面が閉じ、検証一覧へ戻ることを実機確認。

## 回帰検証
- Fast／Full成功。単体140件、Xcode Release、.app、署名。`build/validation/remaining-fast.log`、`remaining-full.log`。
- ThemeSwitchProbe：2つの保持windowでテーマ同期・入力／onAppear回数保持、テーマ復元、native title復帰に加え、Windows 98の終了拒否を尊重し、許可後に閉鎖／cleanupを各1回実行することを確認。`build/validation/remaining-theme-probe.log`。
- 検証器の負例5件を実行。`build/validation/remaining-verifier.log`。

## 配置
通常アプリをメニューから終了し、140件／Full／署名成功のReleaseを/Applications/MyToolBox.appへ反映。Computer Useで再起動後の49ツール一覧を確認。全通常ファイルのSHA-256マニフェストがビルド版と一致し、署名と単一の実プロセスを確認。
実行ファイルSHA-256は`e4bd31139e0d8b4bbe8b8d1bfa71636c1f5e5f45e2998c010caa8df52a91276a`。loginStatus=1を読取確認。成功後に今回の一時旧版.appを削除し、stage／backupが残っていないことを確認。通常アプリのメモ・設定・ログを変更しない。
保存パネルの名前欄へ絶対パスを入れた際にDocumentsへ作られた検証JSONは、合成タイトル／本文を照合して削除。正しく/tmpへ保存したJSONの証拠はbuild/remaining-check/exported-memo.jsonへ保持。

## 残る条件依存の確認
- 日本語IMEの未確定文字のまま終了する操作（AXの直接値設定とIME変換は別）。
- 全ツールの全コピー形式／全テーマ／全サイズ・全ドラッグの組合せ。今回確認した代表例を全組合せ成功とはしない。
- 実sleep/wake、回線切替、再ログイン、8時間以上の安定性、音出し・マイク収録。作業中のMacのスリープ／回線／ログイン・録音許可を自動変更せず未実施として残す。
