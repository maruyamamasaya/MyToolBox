# 追加ツールの一括検証

## 対象
保留されていたローカルメモ、ポート／HTTP、ハッシュ／テストデータに加え、時間・乱数・サーバー／日常計算・ログ・JSON・SQL・正規表現／表／CSV統計を含めて回帰検証。

## 変更
- AddedToolsTests：SHAの空／abc既知値・HEX/Base64・UTF-8／上限、UUID v4、全生成タイプ／件数／区切り／上限／キャンセル、CSV引用の往復、メモJSON互換／不正形式／5世代履歴、ポート／HTTP検索を追加。
- ServerAndEverydayTests：CIDR境界／CRLF1,000行、DNS検証／TXT引用、全単位往復、割合／式／数値集計、全4,096権限往復、Cron／Unix時刻、ツリーJSON／テキスト往復と辞典を追加。
- CIDRのCRLF二重カウントを回帰テストで再現。改行正規化の修正後に成功。
- ポート候補の桁区切りを除去（3,306などを3306へ）。
- メモ保存先とツリー設定の注入、生成画面の初期モード指定を追加し、利用者データと別の環境で検証できるようにした。
- VerifyAddedTools：合成メモ／隔離UserDefaultsによるモデル操作と画面描画。ユーザーメモ・設定・クリップボードを変更しない。

## 検証結果
- Swift単体は専用ログで137件成功（今回16件追加）。最終Fullは並行追加された表CSV読込試験も含め138件成功。`build/validation/batch-tests.log`／`build/validation/batch-full.log`。
- Fast／Full成功：文書、Swift単体、Xcode Release、生成.app、codesign。`build/validation/batch-full.log`。
- 検証器の負例5件成功。`build/validation/batch-verifier-tests.log`。
- VerifyAddedToolsのモデル操作23項目成功。メモの即時保存／再読込・120文字・復元前履歴・書込失敗時の終了抑止／JSON退避／復旧・破損非上書き、生成の古い結果破棄、タイマーボード上限／ID／保存順、ポモドーロ完了、ツリーUndo／Redo／保存、一覧検索、SQL実実行。
- 32画面／モード×3テーマ＝96枚を合成描画。`build/added-tools-preview/`。全体のコンタクトシートと主要画面を目視。Windows 98のAppKit表は合成描画で黒い背景になる箇所があり、cacheDisplayの合成描画と実表示を区別し、実画面での確認を残す。
- Computer Useによる独立したToolCheckプロセスで、ハッシュabc→SHA-256既知値・コピー・入力変更で旧結果消失、生成4モード（20文字×5件／UUID5個／ヘッダー付きCSV5行／文章3件）を確認。
- 同プロセスでポート443→HTTPS・UDPで0件・53ヒントで解除／DNS、HTTP404→Not Found・説明コピーを確認。
- 同プロセスの一時メモでタイトル／日本語・絵文字本文の編集、保存→閉鎖→再表示の一致、履歴と復元キャンセルによる本文保持を確認。検証専用アプリは終了済み。
- ユーザーの保存メモや設定は使用しない。.appの再配置・ログイン設定変更・Git操作はこの検証では行っていない。

## 残す実機項目
各仕様書のチェックリストで、IME未確定時の終了、標準ファイルパネルのキャンセル、全コピー文字列の照合、全画面の狭幅／キーボード／テーマ即時切替、ドラッグ、sleep/wakeなどの未確認操作を維持する。
