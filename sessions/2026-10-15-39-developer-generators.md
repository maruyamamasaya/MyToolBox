# ハッシュとテストデータ生成

- 指定4ページのHTML／JavaScriptを読み取り。ユーザーの統合許可に基づき、ダミー文章・文字列・CSV・UUIDを「テストデータ生成」へ集約、ハッシュは別入口。
- DeveloperGenerators.swiftにCryptoKitハッシュ・サンプル文章／文字列／CSV／UUIDを実装。CSV引用処理は既存実装を共有。
- DeveloperGeneratorView.swiftに専用actor／キャンセル、各設定・結果表示・コピーを追加。
- Catalog／ToolWindows／Launcherへ2入口と旧名検索を登録。Xcode構成再生成。
- 既存の連番付与・CSV閲覧／編集は用途が異なるため維持。
- ビルド・テスト・描画・実機・.app更新は未実施。[仕様と後日テスト](../docs/DEVELOPER_GENERATORS.md)。
