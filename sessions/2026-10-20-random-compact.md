# 乱数ジェネレーターの小窓化

- 利用者指定：カレンダーのサイズを維持し、各ツールを順番に相談して小型化。最初は乱数を選び、設定2行・結果／生成／コピー常時表示の小窓型を採用。「めっちゃ小さくてもいい」を反映。
- RandomNumberViewだけを変更。幅360×高さ260ptを標準とし、最小幅340pt。桁数指定時は追加行で高さ290pt。大きな見出し・カード余白・常設説明を省略。テーマ切替と全生成条件は維持、結果だけスクロール。
- Fast成功。初回Fullはsandbox内で既存署名証明書が見つからず失敗。権限付き再実行でFull成功（Swift単体・Release・署名・55helper）。検証器8件成功、diff check成功。
- 実RandomNumberViewを隔離UserDefaults・非表示NSWindowで4テーマ描画。build/random-compact-previewに保存し、Blue Cosmos／Windows 98を目視確認。fittingSizeは通常360×260、Windows 98はタイトル込み360×290。
- 実画面の操作・桁数指定時の追加行は未検証。本番への配置・起動・終了は行っていない。
