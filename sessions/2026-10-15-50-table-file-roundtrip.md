# 表ビルダーの保存・再読み込み

## Request
表のファイル保存・再読み込みまで実機確認し、問題があれば修正。

## Investigation
ルート規則、CURRENT、OPERATIONS、TESTING、DATA_WORKBENCH、SmallDataToolViews、CSVDocument／CSVGridと既存の保存処理・テストを確認。旧版で保存ボタンを操作しても保存画面が取得できない状態を再現。表にはファイルから直接再読込する入口もなかった。

## Changes
表自身のNSWindowをweak参照で保持し、前面化して非同期の保存／開くシートを表示。NSApp.keyWindowに依存しない。ファイル選択中の二重起動を抑止、キャンセルと書込エラーを表示。保存前にセル編集を確定する。
CSVファイルを開く入口を追加。サイズ・100行・30列を検証し、失敗時は元の表を保持。保存CSVは再読込可能な512KiB以内。SmallDataTools.tableCSVに読込検証を集約。

## Files Changed
SmallDataToolViews.swift、SmallDataTools.swift、RegexAndSmallDataTests.swift、CURRENT／OPERATIONS／TESTING、DATA_WORKBENCH、本記録・索引。

## Validation
Fast／Full成功（138単体テスト、文書、Releaseビルド、署名）、検証器5テストも成功。実ファイル往復テストを追加。
インストール版で保存シート表示→build/table-save-live/table.mdの実保存を確認。
日本語😀・カンマ・二重引用符・セル内改行・末尾空欄を含む3×3表を取り込み、CSVでtable.csvへ実保存。Python標準CSVでも全9セルの一致を検証。
画面を閉じて再度開き、初期サンプル状態から「CSVファイルを開く」でtable.csvを選択。読み込み成功表示と各セルの日本語・引用符・改行・空欄をAXで確認。
HTMLもtable.htmlへ実保存し、ファイル内の表・文字エスケープを確認。保存キャンセル後も表を保持することを確認。

## Result
/Applications/MyToolBox.appへ修正版を配置し、保存・再読込を実機確認。ビルド版とのSHA-256一致、署名、loginStatus=1を確認後、今回の一時旧版バックアップを削除。CSVで再編集可能。Markdown／HTMLは出力用。

## Remaining Issues
全形式・全OS／テーマの全組合せを実機検証したわけではない。代表操作はBlue Cosmosで確認。
