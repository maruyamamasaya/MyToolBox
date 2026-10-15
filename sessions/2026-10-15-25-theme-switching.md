# Living Aurora・Windows 98と全体テーマ切り替え

## Request

ユーザー指定living-aurora-uiを参照し、Living AuroraとWindows 98を追加。後者は色だけでなく造形も再現する。

## Investigation

GitHub接続でdocs/themesとthemes.css、windows-98.css、star-field.tsxを確認。既存Blue Cosmosの固定値とdark Aqua固定を置換。作業中に別作業で追加されたテキスト変換の機能は維持し、選択欄・ボタンだけ共通テーマへ接続。

## Changes

- VisualThemeの3値・保存キー・fallback、ThemeRootによる共有AppStorage→Environment配信。
- 入力モデルを再生成せず全windowへ反映。設定・一覧・各ツールから変更。
- Living Auroraは5光源と49〜73秒の緩やかな漂い、Reduced Motionで静止。
- Windows 98は5色の2段bevel、銀灰・ティール・濃紺、MS Sans Serif系、四角い枠、ボタン・チェック・選択・タブ・進捗・独自ピクセル図案。専用タイトルバーは通常終了・最小化・サイズ変更・ドラッグに接続。
- classic windowはnative titled maskを外し、キー入力可能なNSWindow subclassを使用。戻すと元のstyleMaskを復帰。
- ネイティブのOSダイアログ・フォントfallback等の再現境界はdocs/THEMES.mdに記載。

## Validation

- Fast、Full（Swiftテスト、Release build、codesign）、検証器5テスト成功。
- VisualThemeTests：旧設定既定値、全テーマ永続化、未知／不正値fallback、監視設定非干渉。
- ThemeSwitchProbe：隔離defaultsで保持した2windowを3テーマ間同期、入力・onAppear維持、実ToolWindowのclassic起動・keyboard対応・native title復帰を確認。
- 3テーマ×19ツール画面と5モニター画面を描画。代表画像を確認。classic CSVの保存画像はAppKit周辺にalpha欠落があり、実画面は正常と区別。
- 実アプリでLiving Aurora／Windows 98へ切替、CSVに合成データを表示、通常終了の未保存確認を確認（今回の検証データだけ破棄）。
- 更新後、classic連番windowのnativeタイトル余白がないこと、桁数キーボード選択・チェック・日本語入力を確認。Auroraへ変更して入力「東京／大阪」と結果「01. 東京／02. 大阪」の保持・通常chrome復帰を確認。
- 試験後はBlue Cosmosへ戻し、検証用連番windowを閉じた。

## Result

ユーザーの差し替え許可に基づき/Applications/MyToolBox.appをバックアップ付きで更新。配置元とのdiff一致とcodesign確認。旧版はbuild/app-backups/20261015-155501/MyToolBox.app。

## Remaining Issues

Windows OS全体・全画素の一致ではない。file/date/menuのOS popup、スクロール、権限画面はmacOS。全ツールの全操作・長時間の描画負荷・Reduced Motionの実機切替は未検証。
