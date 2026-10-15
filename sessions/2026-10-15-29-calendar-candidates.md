# カレンダー候補作成と営業日計算の統合

## Request

ユーザー指定Web Calendarの日程候補作成を追加。共通化できる既存ツールへ統合する。

## Investigation

公開ページのweb取得は失敗。GitHub接続でcalendar/index.htmlとapp.jsを確認。単一／複数選択、日別の時間、日付順のテキスト、独自休日を確認。既存BusinessDaysView／ToolCalendar、LocalToolsTests、同梱祝日、ToolWindowsの導線を調査。

## Changes

- 一覧の営業日計算をカレンダーへ変更。ToolID.businessDaysは維持し日程候補／営業日計算の2モードへ統合。
- ScheduleCandidatesに日本時間の日付正規化・複数選択・日別時刻・既定時間・全出力の検証・元版形式の整形を実装。
- CalendarWorkspaceModelが候補・期間・独自休日をwindow内保持し、切替後も復元。
- ToolCalendarを共通化し月外の日付・複数選択・祝日名に対応。既存の営業日用単一選択は維持。
- 祝日推算を追加せず、既存の公式データ1955〜2027年と独自休日を共用。範囲外・データ不在を明示。
- 3テーマに対応。CalendarHolidayEditorで休日編集を共通化。

## Validation

- ScheduleCandidatesTestsの5件：単一／複数、月年越し、切替時の最早日、日別時間、解除／再選択、全体の時刻エラー、うるう日・UTC/JST境界。
- FastとFull（Swift単体、Xcode Release build、codesign）成功。Python検証器5テスト成功。
- RenderLocalToolsにcalendar-candidates固定データを追加し3テーマを描画。Blue Cosmos／Windows 98の候補画面を目視確認。
- 実アプリ：10/15と10/20を複数選択、10/20の開始を11時へ変更、コピー完了表示、10/15の終了を開始と同じ12時にして全出力停止・コピー無効を確認し13時へ復帰。
- 営業日へ切替→今日から1週間で期間7・土日2・営業日5。10/15に検証休日を追加すると休日1・営業日4。候補モードへ戻ると2候補と11時の設定・検証休日が残ることを確認。
- 次月へ移動しても候補一覧と出力を保持。最後に検証windowを閉じ、検証データを破棄。
- 最新版保持ルールに従い、更新中だけ一時コピーを作り、署名・配置元diff一致・起動確認後にその一時コピーのみ削除。

## Result

/Applications/MyToolBox.appを更新し、一覧→カレンダーで候補作成を利用可能。

## Remaining Issues

公式祝日は1955〜2027年、時間は1時間単位・同日内、テキストは元版同様に年を省略。OSカレンダーへの登録や永続保存は行わない。すべての組み合わせの実機操作は未検証。

既存バックアップの一括削除を含む更新案は自動承認レビューで拒否された。既存バックアップを触らない更新方法に変更して完了。今回の更新で作った一時コピーだけを成功後に削除し、以前のバックアップの整理は行っていない。
