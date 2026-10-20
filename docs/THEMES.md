# 共通テーマ

## 切り替えと保存

設定の「テーマ → 外観」、ツール一覧・各ツールの「テーマ」から選択する。既定はBlue Cosmos。共有AppStorageの`appearance.theme.v1`を各ThemeRootが監視し、Environmentで全画面へ伝える。Viewのid変更や入力モデル再生成は行わない。未知の保存値はBlue Cosmosへfallbackする。監視の設定・ログイン登録とは独立。

## デザインの正本

参照はユーザー指定の[living-aurora-ui](https://github.com/maruyamamasaya/living-aurora-ui)。2026-10-15にテーマ仕様・themes.css・windows-98.css・star-field.tsxをGitHub接続経由で確認し、WebのCSSをSwiftUI／AppKitへ移植した。追加の外部ライブラリ、Microsoftの画像・フォントファイルは同梱しない。

- [AppTheme.swift](../Sources/MyToolBox/UI/AppTheme.swift)：色・面・文字・角丸・背景・共有root。
- [ThemeControls.swift](../Sources/MyToolBox/UI/ThemeControls.swift)：ボタン、チェック、選択、入力、進捗、raised/sunken枠。
- [ThemeWindowChrome.swift](../Sources/MyToolBox/UI/ThemeWindowChrome.swift)：window単位の明暗、classicタイトル・終了／最小化／サイズ変更、ドラッグ。
- [ThemeNativeTable.swift](../Sources/MyToolBox/UI/ThemeNativeTable.swift)：CSV見出し・選択色。
- [ThemePixelIcon.swift](../Sources/MyToolBox/UI/ThemePixelIcon.swift)：オリジナル16×16図案。

## Blue Cosmos

濃紺`#020611`、面`#070f22`／`#0a1630`、文字`#edf5ff`、青`#69a7ff`。疎らで決定論的な静止星空。個別ツールの色は維持。

## Living Aurora

背景`#05070c`、面`#0d1220`／`#12192a`、文字`#eef2ff`、紫`#8b6cff`・シアン`#55dde0`。5つの局所的な光が49〜73秒の独立周期で漂う。工具画面向けに明るさと動きを抑える。画面非表示時はSwiftUIの描画ライフサイクルに従う。「視差効果を減らす」で混色した静止構図を維持する。

## シンプルダーク

macOS標準に近いダークグレーの背景・入力面、標準文字色とアクセント色を使用。カードは単色・角丸8pt。背景の星・発光・アニメーションを生成せず、追加の背景描画負荷を抑える。既存のツール配置・操作は共通。

## Windows 98

背景`#008080`、システム面`#c0c0c0`、白`#ffffff`、light`#dfdfdf`、shadow`#808080`、dark shadow`#000000`、タイトル・選択`#000080`。白／lightと黒／shadowの2段bevel、押下時反転、四角い入力欄、チェック、タブ、ブロック式進捗、点線フォーカス、16×16の独自ピクセル図案を使用。blur・glow・背景モーションはない。独立windowのタイトルバーは機能する最小化・サイズ変更・閉じるとドラッグを備える。

参照先と同じくWindows 98のUI文法を再現する。Windows OS全体のエミュレーターではない。フォントはインストール済みMicrosoft Sans Serifを優先し、なければTahoma／macOSの代替フォントを使用する。日本語グリフ・アンチエイリアスはmacOS依存。今回の実機ではMicrosoft Sans Serifを利用できることを確認した。ファイル／日付／メニューのOSポップアップ、スクロール挙動、メニューバー、アクセス許可画面はmacOSの機能を使う。元OSの全画素との完全一致とは区別する。

検証方法は[TESTING](../TESTING.md)。

Windows 98の×は未保存データのdelegate確認を経由して閉じる。borderless windowでnative performCloseが動かない問題を[実機で修正・検証](../sessions/2026-10-15-52-remaining-live-fixes.md)。ThemeSwitchProbeでも終了拒否とcleanup各1回を検証。
