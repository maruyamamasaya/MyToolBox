# カウントダウンの小窓化

- 利用者指定：目標名・残り日数を中心に、設定を歯車へまとめてコンパクトにする。
- PersonalCountdownViewを標準300×280pt（最小280×240pt）の縦スクロールへ。目標名・日数・目標日と時間目標の累計更新は常設。＋で追加、カードの歯車で編集・確認付き削除、上部の歯車でテーマと説明。
- CountdownEditorを幅360ptへ縮小。保存キー・モデル・日数計算・30秒更新・マイカレンダーのViewとサイズは変更なし。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- VerifyPersonalCalendarの描画サイズを小窓へ更新。全Sources（Probe／MyToolBoxApp除外）と同プローブをswiftc -parse-as-library -lsqlite3でcompileし、非表示実行。追加・編集・累計更新・不正入力・保存復元・削除・破損データ保護成功。4テーマのカウントダウン／カレンダー／拡大カレンダー描画成功。build/personal-calendar-previewのBlue Cosmos／Windows 98の小窓を目視確認。検証データは隔離UserDefaults。
- 実画面操作・設定popover・編集sheetは未検証。本番配置・起動・終了なし。
