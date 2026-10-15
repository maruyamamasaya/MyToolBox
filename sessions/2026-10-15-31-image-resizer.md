# 画像リサイズ追加

- 要求：参照Web版の画像リサイズを、実装しやすい方法でMyToolBoxへ追加。
- 公開HTML/JSで30MiB・倍率・縦横比・形式/品質・プレビュー・保存の仕様を確認。
- SwiftUI＋ImageIO/CoreGraphicsを採用。追加ランタイム/パッケージ不要。処理は専用actor。
- ツール一覧16本目。画像選択/ドロップ、幅/高さ、比率維持、25〜200%、JPEG/PNG、品質、プレビュー、別名保存。
- JPEG/PNG/WebP/HEIC/HEIF/TIFFの単一画像を入力。WebP出力は実装せずJPEG/PNGに限定。30MiB・4,000万画素・出力各辺16,384px上限。
- EXIF向き補正・sRGB出力・PNG透明保持・JPEG白背景。入力メタデータは転記しない。
- 元画像と同一パス/symlink/hardlinkを保存先に指定しても拒否。
- ImageResizerTests 6件追加。Fast/Full、81件のSwiftテスト、Releaseビルド・署名検証、検証器5件成功。
- RenderImageResizerで実モデルの読込→縦横比→変換→JPEG保存/再読込・原本不変・設定変更/読込失敗時の旧結果破棄を確認。
- 3テーマで合成画像の画面を描画・目視確認。ファイルパネル/ドロップの実デスクトップ操作は未実施。
- /Applicationsへの配置・起動中アプリの更新は未実施。検証済み最新版.appは標準buildパス。
- 最終Full中に別作業の計算ツール登録が入り、ToolLauncherの色switch不足で一度失敗。不足caseを補い、統合後のFull（Swiftテスト・Release・署名）も成功。
