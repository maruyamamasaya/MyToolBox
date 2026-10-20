# 開発中の非干渉検証と一括デプロイ

## Request
他の作業を妨げない開発時の注意点を文書化し、本番反映はユーザーがまとめて行う。

## Investigation
単体・モデルプローブ・オフスクリーン描画は既存。ThemeSwitchProbeにはorderFrontがあり、すべてのプローブを裏側検証とは扱えない。

## Changes
単体→隔離モデル→実View描画を優先し、実画面の操作は明示依頼時のみ。本番の配置・終了・再起動を通常開発から分離。

## Files Changed
AGENTS.md、docs/DEVELOPMENT_WORKFLOW.md、TESTING.md、OPERATIONS.md、本記録。

## Validation
Fast成功。検証器7テスト成功。Fullは文書・Swiftテスト成功後、指定署名証明書が見つからずXcode build失敗。署名・設定は変更していない。

## Result
方針を文書化し、開発ルールから参照可能にした。アプリ実装・本番配置・起動操作は行っていない。

## Remaining Issues
Fullのビルド・署名確認は未完了。新たな共通テストランナーの実装は今回の対象外。
