# SQLツール

参照：[整形](https://maruyamamasaya.github.io/tool/sql-formatter/)・[説明](https://maruyamamasaya.github.io/tool/sql-explainer/)・[実行](https://maruyamamasaya.github.io/tool/sql-playground/)。ネットワーク・サーバーの「SQLツール」に3タブを統合。入力は共有、処理は明示ボタン、結果はコピー可能。外部サービスや追加パッケージは不要。

## 整形
キーワードの大文字／小文字と、主要句・最上位カンマの改行を行う簡易整形。文字列、引用識別子、コメント、ドル引用符の内容を保持する。閉じていない引用・コメント・括弧はエラー。最大200 KB、括弧64階層。

方言別の構文解析・構文検証・最適化・完全な整形品質は対象外。バックスラッシュは引用内のエスケープとして扱うため、方言やSQLモードによる違いは未対応。数値の計算や文字列の書き換えは行わない。

## 説明
単一の基本SELECTからSELECT／FROM／JOIN／ON／USING／WHERE／GROUP BY／HAVING／ORDER BY／LIMIT／OFFSETを区切り、対象の式と日本語の定型説明を表示。引用・コメント内のキーワードを句と誤認しない。

構文検証・実データの意味の推論・実行計画・AI説明は行わない。WITH、サブクエリ、集合演算、ウィンドウ関数、SELECT INTO、更新系、複数文は明示エラー。その他の方言固有構文や高度な式について正しい説明を保証しない。

## 実行
macOS標準SQLiteのメモリ内DBを専用actorで直列実行。employees（id/name/department/salary/active）とprojects（id/name/employee_id）のサンプルで開始し、SQLによる作成・追加・更新・削除・結合・集計を試せる。複数文の結果を順に表示し、NULLと空文字を区別。コピーはCSV（NULLは文字列NULL表記、BLOBはバイト数の説明）。DBは画面を閉じると破棄。初期化ボタンは確認後にサンプルへ戻す。

- 実DB接続・ファイル読書き・拡張読込・ATTACH・PRAGMA・明示トランザクション・仮想テーブルは非対応。SQLite authorizerで拒否する。
- 最大200 KB／20文／約2秒または約1,000万VM命令。式深さ100・列64・単一値1 MB・メインDB約16 MiBを上限に設定。
- 各結果は先頭500行、文字列の結果総量2 MBまで。500行を超えても文の実行を完了させる。上限やエラー時は今回のバッチ全体をロールバック。過去に成功したバッチは残す。
- SQL方言はSQLite。MySQL／PostgreSQL／SQL Server固有機能、Web版の表直接編集・自動保存は対象外。

## 検証
SQLToolsTestsで引用・コメント保持、整形前後のSQLite実行結果一致、SELECT句説明、実SQLiteの複数文・JOIN・NULL、失敗時ロールバック、外部操作拒否、件数／文数／時間上限と復帰を検証。
実機UIの3テーマ・タブ移動・コピー・初期化確認は未実施。

SQLite API仕様：[authorizer](https://www.sqlite.org/c3ref/set_authorizer.html)、[progress handler](https://www.sqlite.org/c3ref/progress_handler.html)、[prepare](https://www.sqlite.org/c3ref/prepare.html)。
