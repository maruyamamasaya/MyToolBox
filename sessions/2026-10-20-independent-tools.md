# メモ・タイマー独立プロセス

## Request
管理を一つに保ち、メモとタイマーを本体再起動後も継続利用する。

## Investigation
ToolWindowsがすべての画面を本体内に保持していた。保存先・設定とメモのホットキー、タイマーclose時のstopを確認。既存の作業差分を保持して追加変更。

## Changes
4個の同梱helper appを固有ID・共通バイナリで作成。対象ツールのみ独立起動し、再オープン・設定引継ぎ・本体終了からの独立・メモショートカットの登録移譲を実装。

## Files Changed
IndependentTools.swift、ToolWindows.swift、MyToolBoxApp.swift、TimerToolsView.swift、PersonalCalendarView.swift、generate_project.py、embed_tool_apps.py、app_verify.py、test_verify.py、VerifyQuickMemo.swift、関連設計／操作文書。

## Validation
- Fast成功、Full成功（163単体、Releaseビルド、外側＋全4ヘルパーのdeep署名）。検証器7件成功、Python構文とgit diff --check成功。
- VerifyQuickMemo：Native編集・即時保存・Undo/Redo・メモ切替・保存失敗時のclose拒否／復旧、4テーマ描画を成功。隔離UserDefaultsでホットキー登録→移譲（有効設定保持）→ヘルパー役が取得→本体役が再取得も成功。
- 一覧からメモを起動し検証メモ入力、3タイマーを開始。本体を終了しても4ヘルパーはPID 71824 / 75940 / 75942 / 75945のまま。残時間が進み、本体停止中の追記も即時保存。
- 本体を再起動（74561→76183）、一覧からメモとボードを再選択。重複起動せず内容と計測を維持。各ツールの×でそのプロセスだけ終了、本体は継続。
- 初回実機起動で本体自身のIDをsuiteNameに使うとnilになることを確認し、本体は.standard、ヘルパーは既存ドメインのsuiteへ分岐して修正。修正後にFull・実機再起動を実施。
- 最終Fullの新版を/Applicationsへ反映し、deep署名と全28ファイルSHA-256一致を確認。バックアップ・ビルド.appを削除。配置後に本体と一覧→独立メモの起動を再確認。検証用メモ・ボードは削除し、検証計測は終了。

## Result
本体再起動中もメモ編集と3タイマーの計測・操作を継続できる。管理・配布はMyToolBox.appひとつ。

## Remaining Issues
Macの再起動・ツール自身のクラッシュから全入力状態を復元する機能は今回の範囲外。有効なメモショートカットでの本体再起動を伴うキー実入力は未実施（実登録の移譲は隔離モデルで検証）。
