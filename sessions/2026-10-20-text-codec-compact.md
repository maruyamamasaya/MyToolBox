# Base64／エスケープ変換の小窓化

- 利用者指定：方法と方向を上部、入力と結果を上下にまとめ、貼付け・変換・コピーを押しやすく残してできるだけコンパクトにする。
- TextCodecViewを標準320×360pt（最小300×340pt）へ。方式と方向の2選択、入力と結果、状態、貼付け／クリア／変換／コピー。テーマと説明は歯車へ。
- 方式／方向のBindingで既存4モードへ対応。自動変換・遅延更新・キャンセル・警告・UTF-8・入力制限・旧結果コピー禁止は維持。明示の変換ボタンでupdateを再実行。モデルと計算処理・他ツールは変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactTextCodec.swiftは隔離UserDefaults・非表示実Viewで4テーマ×Base64変換／復元／エスケープ／復元／不正Base64の20画面描画。実TextCodecModelのupdate完了後に描画。build/codec-compact-previewのBlue Cosmos変換・Windows 98不正入力を目視確認。
- compile対象：VisualTheme、TextCodec／TextTools／CSVDocument、AppTheme／Theme*.swift、TextCodecViewとプローブ。swiftc -parse-as-libraryを使用。
- 実画面操作・方式／方向切替・popover・スクロール・クリップボードは未検証。本番配置・起動・終了なし。
