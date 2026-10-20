# 青い専用アイコン・一覧修正の配置

## Request / Investigation
アイコン追加ルールを記録し、ここまでの変更をデプロイする依頼。
開始時は本体26822・ウィンドウ配置79620のみ起動。編集用helperは起動していなかった。

## Changes / Files Changed
- 55専用アイコンと一覧の全セル保持を同梱。Fast／Full後に署名・340ファイルのSHA-256／モード一致を確認し、/Applicationsで原子的に交換。
- 初回の本体起動がクラッシュ。クラッシュ記録はToolLauncherGrid.columns(for:)で無限大／NaNをIntへ変換するSwift runtime failureを示した。
- ToolLauncher.swiftで未指定／非有限幅を既定幅へ正規化し、列数をカタログ上限内に制限。再度Fast／Fullを通して配置。
- tools/VerifyLauncherLayout.swiftを追加。実際のresizable: trueの一覧を隔離UserDefaults・非表示ウィンドウで描画し、fittingSize計測も実施。
- 本体とウィンドウ配置は通常終了のみ使用。設定・TCC・ログイン登録の変更や強制終了は行わない。

## Validation / Result
- 修正版Fast／Full成功。170単体・Release build・全55helperアイコン一致・deep署名成功。Python検証器8件成功。
- 可変一覧を4テーマ×3サイズで描画。evidence/launcher-layout/のsimple-dark画像を目視確認。
- CUAで配置先の実一覧を確認。下へ3ページ→上へ3ページとスクロールし、テキスト・CSVの全17アイコンが表示されることを画像で確認。
- 最終PID：本体39826、ウィンドウ配置39825。起動先は/Applications/MyToolBox.app内。
- 起動前後の共有設定（テーマ・お気に入り・shortcut関連・監視設定）のハッシュ一致。
- 配置先340ファイルはビルドと一致。初回失敗版・切替前旧版の一時.appとビルド用.appを成功確認後に削除。
- 証跡：build/validation/icon-deploy/state.json・manifest.json。

## Remaining Issues
間欠的なアイコン消失の長時間再発確認・全ツールのDock／Finder表示・ショートカット実入力は未確認。
今回の再現確認は一覧の起動と1往復のスクロールであり、全操作の保証ではない。
