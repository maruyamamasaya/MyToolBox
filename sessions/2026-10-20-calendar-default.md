# マイカレンダーの標準表示統合

## Request / Investigation
拡大版を標準にし、小型表示を廃止。従来はPersonalCalendarViewの3か月表示からExpandedCalendarViewをsheet表示していた。

## Changes / Files Changed
- PersonalCalendarViewから小型グリッド・拡大sheet・スペース切替を削除し、卓上風1か月表示を直接配置。
- ExpandedCalendarViewの戻る操作をテーマ・ショートカット設定へ置換。月移動・今日・選択日・暦注・30秒更新を維持。
- VerifyPersonalCalendarの標準画面サイズ、仕様文書とCURRENTを更新。

## Validation / Result
Fast・単体170件・検証器7件成功。隔離モデルの保存／破損保護、4テーマ×標準カレンダー／暦注固定日／カウントダウンの12画面描画成功。simple-dark標準画面を目視確認。
Fullは試行したが、並行変更中のToolWindows.swift:18のMainActor分離エラーで失敗。カレンダーを含むToolWindows以外の実ソースはプローブのコンパイル成功。初回の証明書参照制限と同時ビルド時のInfo.plist欠損は再試行した。

## Remaining Issues
本番未反映。実画面での操作は未実施。

## 後続の反映
2026-10-20に[一括デプロイ](2026-10-20-combined-deploy.md)済み。起動中の独立ツールは作業保護のため再起動せず、次回起動から新版を使用。上記検証・未確認事項は実施時点の記録。
