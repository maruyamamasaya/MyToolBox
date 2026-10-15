# カレンダー：日程候補・営業日計算

## 元版と統合

ユーザー指定の[Calendar](https://maruyamamasaya.github.io/tool/calendar/)を追加。[HTML](https://github.com/maruyamamasaya/tool/blob/main/calendar/index.html)と[処理](https://github.com/maruyamamasaya/tool/blob/main/calendar/app.js)を2026-10-15にGitHub接続で確認した。app.js参照SHAは`6f6f188102d082c7de7767837164393f72da9c5e`。Web実装を同梱せず、選択と整形の挙動をSwiftで実装した。

既存の営業日計算とカレンダー・休日を共有できるため、一覧を増やさず「カレンダー」に統合した。内部ToolID.businessDaysは維持。初期表示は日程候補、タブで営業日計算へ移る。ウィンドウを開いている間は候補・日別時間・営業日範囲・独自休日を保持し、テーマやモード切替では消えない。閉じると破棄し、永続保存しない。

## 日程候補

- 1日だけ／複数候補を切り替える。単一モードではクリックした日へ置換し、同日クリックでは解除しない。
- 複数モードはクリックで追加・解除。月外の日を含む6週を表示し、月をまたいだ選択を保持する。単一へ戻すと日付順で最初の候補を残す。
- 新規候補の既定時間は12〜13時。9〜21時のバーで開始点→終了点をクリックして1時間単位で変更する。選んだ時間帯を塗り、開始・終了・時間数を表示する。新規候補の既定時間と日別時間に同じバーを使用し、既定を変えても選択済みの日は変わらない。
- 逆順の2点は前後を並べて確定する。同じ点の2回クリックは0時間として確定しない。途中はコピーを停止し、キャンセルで確定済みの時間へ戻せる。新規時間を選びかけている間は日付追加も一時停止する。
- 解除して再選択した日の時間は同じwindow内で保持。「すべて解除」は時間の記憶もクリアする。
- 終了は開始より後。日をまたぐ時間指定はしない。不正な候補が1つでもあると全体の出力・コピーを止める。選択がなければ出力は空。
- 日本時間の日付へ正規化し、日付順に`10月15日（木）　12：00　〜　13：00`を出力。複数モードは各行の先頭に`・`を付ける。元版同様、年は出力しない。
- 明示したコピー以外に外部アプリへ送信しない。EventKitやアカウント接続は使用しない。

## 共通休日と営業日

公式祝日は既存の内閣府データ（1955〜2027年）を使用する。元Web版の祝日推算は移植しない。範囲外・取得不能を「祝日なし」と断定せず、注意文を表示する。日程候補は対応外の年でも選べるが公式祝日表示は行わない。

独自休日は名前付きで追加・削除し、両モードのカレンダーと営業日計算へ即時反映する。独自休日も候補として選べる。自動除外はしない。営業日計算の定義・同梱データの由来は[ローカルツール](LOCAL_TOOLS.md)。

## 実装・検証入口

- [ScheduleCandidates.swift](../Sources/MonitorKit/Tools/ScheduleCandidates.swift)：選択・検証・出力。
- [CalendarWorkspaceView.swift](../Sources/MyToolBox/Tools/CalendarWorkspaceView.swift)：window内状態、2モード、休日の編集。
- [BusinessDaysView.swift](../Sources/MyToolBox/Tools/BusinessDaysView.swift)：営業日UI。
- [ToolDesign.swift](../Sources/MyToolBox/Tools/ToolDesign.swift)：共通カレンダー。
- [HourRangeBar.swift](../Sources/MyToolBox/Tools/HourRangeBar.swift)：時間帯のクリック選択と範囲描画。
- [単体テスト](../Tests/MonitorKitTests/ScheduleCandidatesTests.swift)、[検証方法](../TESTING.md)。
