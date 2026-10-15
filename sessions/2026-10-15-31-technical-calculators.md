# 2026-10-15 計算ツール5本

- ユーザー指定の公開5ページとJavaScriptを読み取り、容量・進数・帯域・RAID・SLAをネイティブ実装。
- TechnicalCalculatorsに純粋計算、TechnicalCalculatorViewに共通テーマの独立画面。Catalog／Windowsへ登録。
- 多桁進数は長除算、最大1024桁。無効入力・非有限値・構成制約を検証し、古い結果を表示しない。
- Fast／Full（86テスト・Releaseビルド・署名）成功。検証器の5テスト成功。
- 3テーマ×5画面をオフスクリーン描画、Blue Cosmosの5画面を目視確認。
- 実機入力・コピー操作は未確認。/Applicationsへの配置・稼働中アプリの再起動は行っていない。
- 既存の未コミット変更を保持。詳細は[仕様](../docs/TECHNICAL_CALCULATORS.md)。
