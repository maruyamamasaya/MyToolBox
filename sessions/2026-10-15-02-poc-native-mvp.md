# 2026-10-15：PoCとネイティブMVP

## Request
M1 Max向けParallels Toolbox代替をPoCから開発。Xcode/.app、測定根拠、MVPと実在する検証を要求。途中のUI参考画像に合わせ2段メニューバーへ変更。

## Investigation
開始時は文書と文書verifyのみ、Gitなし。AGENTS/CURRENT→設計/CODEMAP/検証/運用/判断→SDKとrgで探索。ローカルsemantic index・IDE symbol toolなし、未利用。実機はM1 Max/32 GiB/P8 E2。公開Apple資料とSDKを参照し、第三者実装のコピーなし。

## Changes
共通MonitorKit、CPU/GPU/Memory/Network/Storage/Battery/Sensorsの独立collector、actor直列取得、CLI PoC、差分/履歴/設定、SwiftUI詳細・設定とAppKitメニューを追加。非公開キー・推定・未対応は明記。ログイン起動は明示操作限定。

参考画像に合わせ、Network上下速度・CPU%・RAM/SSD容量・BAT%の2段表示、区切り線、表示順・非表示・compactを実装。GPU/Sensorsも設定で追加可能。

## Files Changed
Sources、Tests、Package.swift、MyToolBox.xcodeproj、Resources、tools、scripts、docs、evidenceを追加／更新。状態が変わったルート文書とdecisions/0002を更新。AGENTSの変更・子AGENTS追加なし。

## Validation
- Fast：文書＋Swiftテスト成功。Full：文書＋Swiftテスト＋Xcode Release＋codesign成功。
- Swift XCTest 12件（取得不能、差分、IF変更、reset、保存、単位、60秒保持等）。検証器の隔離負例3件も成功。
- 通常ユーザーPoC 5サンプル成功。Sandbox PoCではNetwork不可でも他カテゴリ継続を確認。
- CPU負荷30.5–31.7%→50.5–81.6%→30.6–38.2%、GPU0–8%→87–90%→0%、loopback約1.2MB/sへ増加後低下。
- .app起動、約3分のプロセス常駐確認。一点でCPU0.5%、RSS約110MiB（旧UIビルド）。
- Computer Useは2回timeout。UI操作・実メニューバー目視は未検証。2段部品は実測サンプルでオフスクリーン描画確認。

## Result
初期MVPとローカル実行用.appを作成。取得可能な主要指標のPhase 1と自動検証まで進めた。全機能完成・Parallelsからの移行完了とはしない。

## Remaining Issues
温度・Fan・電力、GUI操作、実IF切替、実sleep復帰、8時間以上の安定性、ログイン起動の実登録、Parallels比較、推定値の校正。再現手順と合否基準はdocs/MIGRATION_CHECKLIST.md。Git/CI、配布署名・公証は未整備。
