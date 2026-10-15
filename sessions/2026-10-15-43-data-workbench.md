# 正規表現・表・CSV統計の4ツール

## Request
正規表現テスター・ビルダー、表ビルダー、CSV統計を追加。大容量対応は不要で手軽に使う。

## Investigation
ルート規則・CURRENT・CODEMAP・TESTING・ARCHITECTURE・OPERATIONS、元WebのHTML／JS、StringReplacer、CSVDocument／CSVGrid、既存テスト・登録導線を確認。

## Changes
テキスト・CSVへ4入口を登録。ICU正規表現の一致・キャプチャ・置換、12部品と6プリセットの組立、表の直接編集とMarkdown／HTML／CSV出力、CSV／TSVの欠損・重複・型・数値統計を実装。処理はローカル。小さな入力上限と正規表現の進捗時間上限を設定。

## Files Changed
RegexWorkbench.swift、SmallDataTools.swift、RegexToolViews.swift、SmallDataToolViews.swift、RegexAndSmallDataTests.swift、RenderDataWorkbench.swift、ToolCatalog／ToolWindows／ToolLauncher、生成Xcode構成、CURRENT／CODEMAP／TESTING、DATA_WORKBENCH.md。

## Validation
追加の9テスト（Unicode、キャプチャ、置換、フラグ、病的な正規表現の中断、部品生成、出力形式、CSV集計・不正入力）を含むFast成功。検証器5テスト成功。最終Fullも成功（Releaseビルド・署名確認）。4画面×3テーマの描画12枚を生成し、Blue Cosmosの4画面とWindows 98の統計画面を目視確認。実デスクトップの操作検証とは区別する。同時編集中の別画面に一時コンパイルエラーがあり、解消後に全体を再検証した。

## Result
4画面と一覧導線を実装。/Applications版の更新は今回実施していない。

## Remaining Issues
実デスクトップでの操作は未確認。同時進行の別ツールの変更は保持。
