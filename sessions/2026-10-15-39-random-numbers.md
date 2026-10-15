# 乱数ジェネレーター追加

## Request
指定WebツールをMyToolBoxへ追加。

## Investigation
AGENTS／CURRENT／CODEMAP／ARCHITECTURE／TESTING／OPERATIONS、既存カタログ・専用window・共通画面、公開HTML／app.jsを確認。

## Changes
計算・変換カテゴリへ専用ネイティブ画面を登録。6範囲、1〜32桁、0始まり、6個数、5区切り、コピーを実装。桁数指定は文字列で精度維持。区切り変更では再抽選しない。

## Files Changed
RandomNumbers.swift、RandomNumberView.swift、RandomNumbersTests.swift、ToolCatalog、ToolWindows、ToolLauncher、生成Xcode構成、CURRENT、CODEMAP、仕様文書。

## Validation
Full：97単体テスト成功、Releaseビルド成功、署名検証成功。検証器5テスト成功。Fastも再実行して成功。

## Result
build/Build/Products/Release/MyToolBox.appへ反映。/Applications版の更新は今回実施していない。

## Remaining Issues
実機UI操作は未確認。既存作業中の変更は保持。
