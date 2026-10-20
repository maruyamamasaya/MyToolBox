# マイカレンダー・カウントダウンの独立プロセス

## Request
2ツールを別プロセスへ追加し、ショートカット・保存設定を引継ぐ。本体再起動中も継続する構成を実装し、バックグラウンドで検証。デプロイ・本番再起動・実画面操作なし。

## Investigation
IndependentTools・ToolWindows・AppDelegateのhelper分岐を再利用。PersonalCalendarModelは.standardを使用していたため、helper側でも既存local.MyToolBoxの保存先へ接続する必要あり。カレンダーはJapaneseHolidays.jsonをBundle.mainから読むため同梱が必要。

## Changes
- personalCalendar／personalCountdownを固有bundle IDの同梱アプリへ追加。既存の目標・ショートカット・テーマ設定を共有、祝日データをカレンダーへ同梱。
- メモとカレンダーのショートカット所有移譲をIndependentShortcutCoordinatorへ共通化。本体再起動時は起動中helperの登録を取り上げず、終了イベントで登録を戻す。
- ToolShortcutModelを専用ファイルへ分離。restore時に最新キーを読み直し、登録失敗や復元処理で有効設定を消さない。登録境界を注入可能にしてOSのグローバルキーを触らず検証する。
- ヘルパーID・実行ファイル・祝日同梱をビルド検証対象へ追加。

## Validation
- Fast成功、Full成功：167単体・Releaseビルド・6つのhelperのID／実行ファイルとdeep署名。Python検証器7件成功、Python構文・git diff --check成功。
- VerifyIndependentShortcuts：11項目成功。隔離UserDefaultsとテスト用登録境界でキー復元・メモ非干渉・移譲・本体再作成・終了イベント・キー変更・起動失敗・明示OFF・登録競合からの復旧を確認。OSホットキーは登録しない。
- カレンダーhelperのJapaneseHolidays.jsonが親アプリの同梱データと完全一致することを確認。
- VerifyPersonalCalendar：目標追加・編集・累計更新・再読込・不正入力・削除・破損時の非上書きを確認。祝日読込と4テーマ×小型／拡大／カウントダウン12画面のオフスクリーン描画成功。simple-darkの小型・カウントダウン画像を目視確認。
- プローブはactivationPolicy=.prohibited、AppStorageと保存先を隔離。実OSキーの登録を禁止するテスト用登録境界を使用。本番ウィンドウ・クリップボード・ログイン／権限設定へ操作なし。
- 最初の描画プローブは並行作業による入力ソース更新でコンパイル失敗。必要な28ソースを一時コピーして固定し、再コンパイル・実行成功（仮UI／代替モデルは使用しない）。

## Result
実装とバックグラウンド検証完了。本番未反映。次回デプロイ用の.appはbuild/Build/Products/Release/MyToolBox.appに保持。

## Remaining Issues
実際のキー入力・本体の終了／再起動・起動済み画面の再表示は実機未確認。ユーザー指定により本番操作は行わない。カウントダウンには従来どおり専用グローバルキーを追加しない。

## 後続の反映
2026-10-20に[一括デプロイ](2026-10-20-combined-deploy.md)済み。起動中の独立ツールは作業保護のため再起動せず、次回起動から新版を使用。上記検証・未確認事項は実施時点の記録。
