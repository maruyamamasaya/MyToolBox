# サーバー・ネットワーク・日常計算ツール

2026-10-15：ユーザー依頼で11本の実装を追加。**ビルド・Fast/Full・単体テスト・描画・実機確認は未実施**。並行作業のマージ後にまとめて確認する指定のため、検証用プロセスや.app更新を行っていない。テストコードの追加ではなく、[後日実施する項目](SERVER_AND_EVERYDAY_TEST_PLAN.md)を記録した。

## 入口と共通仕様

- ToolCatalog → ToolWindowsから各独立windowを開く。同じツールの再選択では既存windowを前面表示。
- 「ネットワーク・サーバー」カテゴリ：CIDR、DNS、Cron、Linuxコマンド、chmod、ディレクトリツリー、Unix時刻。
- 「計算・変換」カテゴリ：単位変換、パーセント、電卓、数値集計。
- 既存の検索・お気に入り・3テーマを利用。結果には項目別／全体コピーを用意。
- アプリ実行時は外部通信・コマンド実行・DNS登録・権限変更を行わない。
- ディレクトリツリーのみUserDefaultsへ自動保存。JSONファイルの書出しは明示操作。ほかの入力・履歴はwindow内だけ。

## 参照範囲

[CIDR Analyzer](https://maruyamamasaya.github.io/tool/cidr-analyzer/)、[DNS Record Builder](https://maruyamamasaya.github.io/tool/dns-record-builder/)、[Unit Converter](https://maruyamamasaya.github.io/tool/unit-converter/)、[Percentage Calculator](https://maruyamamasaya.github.io/tool/percentage-calculator/)、[Simple Calculator](https://maruyamamasaya.github.io/tool/simple-calculator/)、[Number Calculator](https://maruyamamasaya.github.io/tool/number-calculator/)の画面機能を参照。Web取得が失敗したため、対応するGitHubリポジトリのHTMLと既存のローカル参照資料を確認した。

Linux系は[以前の調査](../sessions/2026-10-15-25-linux-reference-review.md)の5本を対象とすることをユーザーに確認。参照コード・辞書データは転用せず、Swiftで独自実装。特に辞典は参照版の162件を移植したものではない。

## 実装した機能

| ツール | 機能・仕様 | 主な制約 |
| --- | --- | --- |
| CIDR解析 | 複数行のIPv4/CIDR、空白・/整形、マスク・範囲・件数、同一ネットワークのグループ、最も近い親への包含関係 | /0〜/32、1,000行・100KB。IPv6なし。/31は2ホスト、/32は1ホスト |
| DNSレコード作成 | A/AAAA/CNAME/MX/TXT、TTL・優先度検証、追加・個別削除・全削除、ゾーン出力 | 1,000件まで。TTLは0〜2147483647。MX優先度0〜65535。ゾーン全体の競合検出は未実装 |
| 単位変換 | 長さ・重さ・面積・容量・温度・データ容量・時間・速度・圧力・通貨、単位入替、小数0〜10桁 | 通貨は手入力レート。畳1.62m²、米液量gallon。データ1000/1024切替 |
| パーセント計算 | 増減率・差額・前年比・倍率、割合、○%分・増加後・減少後、逆算 | 負数対応、分母0・逆算−100%を拒否 |
| 電卓 | 四則演算・括弧・単項符号・指数表記、自動計算、明示計算で履歴へ追加 | 最大1,000文字・深さ64・履歴20件。スクリプト評価は不使用 |
| 数値集計 | 合計・平均・件数・最大・最小・中央値・範囲、無効トークンの除外表示 | 20,000件・500KB。カンマは区切りなので千区切りなしで入力 |
| Cron解読・作成 | 5フィールド検証、条件一覧、タイムゾーン指定の次回5件、毎分/時/日/週/月の式作成 | 数値・*・範囲・リスト・*/n・範囲/n、曜日0〜6。名前・7=日曜・@特殊構文は非対応 |
| Linuxコマンド辞典 | 独自記述40件、用途・例・主オプション・補足、カテゴリ・複数語AND検索 | GNU/Linux中心の主要項目。網羅辞典ではなく、実行先のman/--helpの代替ではない |
| chmod計算 | 3/4桁8進数・9文字記号の相互変換、rwxとsetuid/setgid/stickyのチェック、コマンド例 | 所有者などの属性変更なし。コマンドの対象パスは例示 |
| ディレクトリツリー作成 | 名前編集、ルート/子追加、子を含む削除・上下移動・階層移動、7出力形式、テキスト/JSON取込・JSONファイル保存 | 1,000項目・深さ20。上下ボタンで並べ替え。ドラッグ・折りたたみは未実装 |
| Unix時刻変換 | 秒/ミリ秒明示指定、日時との相互変換、日本時間/UTC、ISO 8601、現在時刻入力 | 西暦1〜9999年、日時入力は秒精度、Unix秒は小数3桁・ミリ秒は整数へ丸め |

### 補足

- CIDRは不正行を表示し、正常行の解析を続ける。/31・/32の「ブロードキャスト」欄は範囲の末尾であり通常のブロードキャスト用途を表さない。
- DNSホストは@・ワイルドカード先頭ラベル・underscoreに対応。宛先ドメインはASCIIで、IDNはPunycode入力。CNAME/MX宛先には末尾の.を付加。
- TXTは引用符・バックスラッシュをエスケープしUTF-8の255バイト以下へ分割、空文字・制御文字・4096バイト超を拒否する。入力の前後空白を保持。
- DNSの重複・CNAMEと他タイプの共存などレコード間整合性は検査しない。
- 数値はDoubleによる近似。NaN・無限大・計算オーバーフローはエラー。丸めで0になる極小値は指数表記。
- 集計は無効トークンを除外して件数と先頭20件を表示し、入力変更で旧結果を消す。
- Cronは日と曜日の両方を限定した場合OR、どちらかのフィールドが*で始まる場合AND。次回は現在より後の8年以内を探索。実在しない日付や夏時間欠落を飛ばす。夏時間の重複は最初の1回のみ。
- 辞典の検索は名前だけでなく例・オプション・補足も対象。検索結果外の選択項目を表示し続けない。
- ツリーの自動保存キーは`tools.directoryTree.v1`。独自JSONはUUID/name/folder/depthの平坦配列。壊れた保存データは読込エラーとし、編集するまで元データを上書きしない。Undo/Redoは最大50世代・window内のみ。
- ツリー取込は2スペース字下げ、標準Tree・ASCII。子を持つ項目はフォルダへ補正。参照Web版固有JSONとの互換は保証しない。カスタム形式の再取込は非対応。

## ファイル

- `EverydayCalculators.swift` → `EverydayCalculatorViews.swift`：単位・割合・式・統計。
- `NetworkBuilders.swift` → `NetworkBuilderViews.swift`：CIDR・DNS。
- `ServerUtilities.swift`／`CommandReference.swift` → `ServerUtilityViews.swift`：chmod・Cron・Unix・辞典。
- `DirectoryTree.swift` → `DirectoryTreeView.swift`：構成モデル・整形・編集・保存。
- Xcodeプロジェクトは追加ファイルを含むよう再生成。ビルド成功は未確認。
