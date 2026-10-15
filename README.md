# MyToolBox

ローカル完結のmacOSツール集。最初のツールとしてApple M1 Max向けシステムモニターを搭載。Swift / SwiftUI / AppKit製、外部サーバー・有料API・外部依存パッケージ不要です。

PoCと初期MVPを実装しました。CPU・P/E・GPU・RAM・通信・ストレージ・バッテリーの実機取得とXcodeビルドを確認済みです。CPU/GPU温度・ファン回転数もM1 Maxで取得確認済みです。UI目視・長時間稼働・Parallels Toolboxとの比較は未検証です。移行完了ではありません。

## ビルド・実行

macOS 14以上、Apple Silicon、Xcodeが必要です。今回の実証はmacOS 26.6.2 / M1 Maxのみ。

```sh
python3 scripts/verify.py
open build/Build/Products/Release/MyToolBox.app
```

生成済みアプリ：[MyToolBox.app](build/Build/Products/Release/MyToolBox.app)。Xcodeでは[MyToolBox.xcodeproj](MyToolBox.xcodeproj)を開き、MyToolBoxスキームを実行します。

専用の四角グリッドアイコンからツール一覧を開けます。営業日計算・オーディオチェック・マイクチェック・CSVビューワー・CSVエディターに加え、連番テキスト生成・クリップボード整形・テキストクリーナーもローカルで利用できます。[初期5本](docs/LOCAL_TOOLS.md)、[テキスト3本](docs/TEXT_TOOLS.md)、[行・置換・リスト5機能](docs/LINE_TOOLS.md)。行ツール（並べ替え・抽出・重複確認）と検索・置換を追加し、リスト変換はクリップボード整形に統合しています。既存の数値メニューバーは維持し、クリックすると7カテゴリの詳細・60秒グラフ・設定・終了を表示します。ログイン起動は設定画面でユーザーが有効にした場合だけ登録されます。

## 案内

- [現在地](CURRENT.md)
- [AI作業ルール](AGENTS.md)
- [構造とデータフロー](ARCHITECTURE.md)
- [検索の入口](CODEMAP.md)
- [検証方法](TESTING.md)
- [ビルド・起動・運用](OPERATIONS.md)
- [技術検証結果と指標の定義](docs/TECHNICAL_VALIDATION.md)
- [温度・ファンの定義と証拠](docs/SENSORS.md)
- [ツール集のロードマップ](docs/ROADMAP.md)
- [今後の可視化案](docs/VISUALIZATION_ROADMAP.md)
- [第三者ライセンス](THIRD_PARTY_NOTICES.md)
- [機能一覧・既知の制約](docs/FEATURES.md)
- [実機検証・移行チェックリスト](docs/MIGRATION_CHECKLIST.md)
- [設計判断](decisions/README.md)
- [作業履歴](sessions/README.md)

設定はUserDefaultsへ保存。画面用履歴はメモリ内60秒、任意の定期ログはローカルJSONLへ保存します。配布用署名・公証は未対応で、生成物はローカル実行用のad hoc署名です。
