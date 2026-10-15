# AI作業ルール

## 開始と探索

1. この文書と [CURRENT.md](CURRENT.md) を読む。
2. 必要な範囲だけ [ARCHITECTURE.md](ARCHITECTURE.md)、[CODEMAP.md](CODEMAP.md) を読む。
3. 運用変更は [OPERATIONS.md](OPERATIONS.md)、設計判断は [decisions/README.md](decisions/README.md) から探す。
4. 検索で対象を絞り、対象パスの祖先にあるAGENTS.mdを追加ルールとして確認する。
5. definition → references → tests → configuration → data dependencies を確認してから変更する。

概念しか分からない場合は利用可能なsemantic / repository searchを使い、結果を実ファイルで確認する。正確なsymbolはIDE symbol search、呼び出し元はreferences search、文字列は `rg` / `git grep` を使う。semantic indexがなければCODEMAPの語彙から検索する。ツール未提供を利用済みと記録しない。

コンテキストは「ルール・現在地 → 関連設計・CODEMAP → 検索結果 → 対象ファイル → 依存・テスト」の順で増やす。全ソースの一括読み込みを避ける。

## 変更と安全

- 実装事実、意図した仕様、過去の判断、不具合を区別する。不明点を推測で確定しない。
- 要求範囲を守り、小さな変更を優先する。検索性だけの大規模renameや不要な依存追加を避ける。
- 関連テストを先に調べ、取得不能な監視値を架空の値や0で補わない。
- 管理者権限、システム設定変更、破壊的操作は実行前に確認する。外部送信や秘密情報の記録を行わない。
- 子AGENTS.mdは独立したスタック・検証方法・変更ルール・強い責務境界が実在する場合だけ作る。架空のアプリ領域には作らない。

## 検証・終了

[TESTING.md](TESTING.md) の変更別マップに従い、実装中はFast、完了前はFullを実行する。実行不能・未確認・失敗を成功と区別する。

文書の正本は役割別に一つにし、詳細はリンクする。ルートAGENTSは120行、CURRENTは80行、CODEMAPは160行、sessionは100行を目安に保つ。超過時は意味のある分割を検討する。

更新条件：CURRENTは現在状態、ARCHITECTUREは構造、CODEMAPは入口・配置、TESTINGは検証方法、OPERATIONSは起動・運用が変わった時だけ更新する。重要判断はdecisionsへ、作業終了時はsessionsへ簡潔に記録する。全ファイルを毎回更新しない。
