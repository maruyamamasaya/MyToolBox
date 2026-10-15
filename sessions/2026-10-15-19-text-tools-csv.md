# CSV実機試験・テキスト3ツール・アイコン一覧
Date: 2026-10-15

## Request
CSV編集/保存/再読込の実機試験と不具合修正。連番テキスト生成、クリップボード整形、追加依頼のテキストクリーナーをローカル化。色の特色を活かし一覧をアイコン化。

## Changes
- 参照Gitの対象3ディレクトリapp.js/test.js/index.htmlを検索・確認し、Swift独立実装。Web取得は失敗、既存cloneのrevisionとライセンス方針を継承。
- TextTools.swiftに連番・表整形・クリーナー。TextProcessor actorで直列変換、入力待ち/キャンセル、1MiB入力・4MiB結果上限。Plain NSTextViewの元文/結果。
- 全9ツールを3列アイコンへ。連番indigo、整形teal、クリーナーpink。他の色も維持。
- CSVの貼付け/編集欄併用ではみ出す問題を固定ヘッダー＋スクロールで修正。
- 表内編集開始で選択を再適用しフォーカスが外れる問題を、選択差分と明示doubleActionで修正。MainActor上で処理。
- 保存/ソート/行列変更、整形のコピー前に編集確定。保存側8MiB上限で再読込可能性を維持。

## Actual UI validation
- baseline：日本語/カンマ/引用符/セル内改行を貼付け、改行セルを編集、NSSavePanel保存、NSOpenPanel再読込、ファイル解析一致。
- final：表の2行1列をダブルクリックし「東京・表内編集済み」へ貼付け、Tab/Returnなしで別名保存。再読込で編集値・引用符・セル内改行を確認、Python csv解析で全4×3セル一致。evidence/csv-ui/final-result.json。
- 貼付け欄とセル編集欄を開いたまま下端へスクロール、タイトル/操作欄/編集欄が使用可能。保存済みcloseで警告なし。
- CUAのtypeTextは日本語入力に反映されない場合があり、実際の貼付けと値確認で再試験。API失敗/timeout時は状態を再取得。
- 連番：空行除外/採番、開始10・増分10・区切り:で10:東京/20:/30:大阪。不正増分abcでエラーとコピー無効。
- 整形：タブ3列判定、列3除外・重複除去、SQL INのO''Reilly、表の編集→結果反映。未確定セルを99へ変更→コピー→貼り直しでA,B改行99,2の一致確認。
- クリーナー：CR/連続空行/単独・/NBSP/ゼロ幅/BOMを含む入力から期待した結果。元文を保持。
- 検証windowを閉じ、アイコン一覧へ戻した。テストファイルのみ保存しユーザーの既存CSVは変更していない。

## Automated validation / delivery
- Fast/Full、Swift40件、文書検証器負例3件、Xcode Release/.app/codesign成功。
- 新3画面を含む9画面のオフスクリーン描画。証拠はevidence/tool-*.png。
- /Applicationsを通常終了後・バックアップ付きで更新。最終バイナリSHA一致、loginStatus=1。
- 大量入力の長時間UI操作、CSV未保存確認の全分岐、音出し/マイク実録音、sleep/IF切替/再ログイン/Parallels比較は未検証。

## References
[テキスト3ツール](../docs/TEXT_TOOLS.md)、[初期5本とCSV試験](../docs/LOCAL_TOOLS.md)。
