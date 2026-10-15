# 乱数ジェネレーター

参照：[Web版](https://maruyamamasaya.github.io/tool/random-number-generator/)。ネイティブ画面で端末内生成し、通信・自動保存は行わない。

- 範囲：1〜10、1〜100、1〜1,000、0〜255、-100〜100、-1,000〜1,000。
- 桁数指定：1〜32桁。通常は先頭1〜9。「0から開始する」は0〜指定桁数の最大値で、先頭0を省略する。
- 個数：1／5／10／20／50／100個。重複を許す。
- 区切り：改行／カンマ＋空白／空白／タブ／空白付きパイプ。変更しても再生成しない。
- 起動時・条件変更時・生成ボタンで生成。結果の選択・コピーに対応。不正な桁数はエラーを表示しコピーを無効化。

SystemRandomNumberGeneratorとSwift標準の範囲内乱数を使用。32桁は各桁から文字列を生成し、浮動小数点や固定長整数への変換による桁落ちを避ける。

処理：`RandomNumbers.swift` → `RandomNumberView.swift` → ToolCatalog／ToolWindows。
単体テスト：`RandomNumbersTests.swift`（範囲、件数、32桁、0始まり、不正入力）。実機UI操作は未確認。
