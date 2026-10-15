# カラーパレット追加

- 参照：https://maruyamamasaya.github.io/tool/color-palette/ （ブラウザ表示を確認）。
- ツール一覧にネイティブ画面を登録。120色、HEX/RGBコピー、2色と4方向のCSSグラデーション、8おすすめ、UserDefaults自動保存メモを実装。
- 外部通信・追加依存なし。入力不正時は変換結果を表示せずコピーを無効化。
- PaletteColorTests：3/6桁HEX、RGB境界、不正入力、120色の件数/一意性、おすすめCSS。
- Fast、Full（70テスト・Release build・署名）、検証器5テストが成功。
- 3テーマのオフスクリーン描画成功・目視確認。画像はevidence/themes/<theme>/tool-color-palette.png。実デスクトップ操作とは区別。
- /Applicationsのアプリ更新・実デスクトップ操作は未実施。ビルド成果物は固定パスに生成。
