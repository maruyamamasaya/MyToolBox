# 時間計算の小窓化

- 利用者指定：勤務時間の入力と結果を小窓へ、時間帯の合計はタブに分け、できるだけコンパクトにする。直前の押しやすいボタンの希望も継承。
- TimeCalculatorViewを幅300pt（最小280pt）、勤務時間320pt／複数行360ptの高さへ。開始・終了・休憩は横3欄。結果は時間分・小数時間／合計分・実時間を凝縮。コピー・リセット常設、テーマと説明は歯車popover。
- 計算APIとコピーするレポート形式を維持。入力とモード変更でコピー完了表示を解除。カレンダー等は変更なし。
- Fast・最終Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderCompactTimeCalculator.swiftをVisualTheme、TimeCalculation、AppTheme／Theme*.swift、TimeCalculatorViewとswiftc -parse-as-libraryでcompile。隔離UserDefaults・非表示NSWindowで4テーマ×勤務／複数行／日跨ぎ／不正時刻／不正行の20画面描画成功。初回の複数行で下部ボタンが欠けたため高さ360へ調整して再描画。build/time-calculator-compact-previewのBlue Cosmos勤務／複数行と調整前Windows 98複数行を目視確認。
- 実画面の物理操作・タブ切替時のウィンドウ追従・設定popover・クリップボードは未検証。本番配置・起動・終了なし。
