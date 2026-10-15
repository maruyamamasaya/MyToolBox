# 0002：共通取得ライブラリとローカルMVP

Status：採用・初期実装済み
Date：2026-10-15

## Context
[0001](0001-local-native-foundation.md)で設けた文書基盤の次に、ユーザーが実機PoC、Xcode/.app、MVP、アプリ検証までの開発を依頼。M1 Max実機で主要カウンターが読めた。温度・Fanの方式は未検証。

## Decision
Swift PackageのMonitorKitをCLIとテストで共有し、native Xcode targetにも同じファイルを直接含める。追加package・xcodegen等を不要にするため小さなPython生成器でpbxprojを管理する。Actorで取得を直列化し、UIはMainActor。値はavailable/waiting/unavailable/notPresent。欠損を0へ変換しない。

CPUトポロジーはlogical-cpu-id/cluster-typeを照合、GPUはIOAcceleratorのsystem-wide統計、ネットワークは単一IFの64-bitカウンター、Diskはdriver層だけを集計する。非公開キーは互換性保証なしとして記録。温度・Fan・電力は推測値を実装せず未対応。RAM使用量とBattery容量は推定と明示する。

App Sandboxなし・特権ヘルパーなし・通常ユーザー読取専用・外部通信なし。ログイン起動は明示UI操作に限定。メニューバーはユーザー追加画像に合わせた2段表示、RAM/SSD使用容量・通信上下・項目区切り線。

## Reason
PoCと実アプリの取得方式を一致させ、制限された項目だけ失敗できる構造にする。最小依存でローカル実行成果物を作り、自動検証と未実施の実機試験を分ける。

## Alternatives
全項目をpowermetricsへ依存する方式は管理者権限要件のため不採用。非公開センサーコードを無調査でコピーしない。Metal自プロセス測定をGPU全体使用率と見なさない。複数IFやAPFS volumeの単純合算は重複を生むため不採用。

## Consequences
OS/機種によるキー変更を継続検証する必要がある。GUI目視・sleep・実IF切替・長期安定性・Parallels比較・ログイン起動実登録は次の検証。生成器にビルド設定を集約し、新ソース追加時は再生成する。Developer ID署名／公証は別作業。

0001の「今回は文書のみ」は当時のスコープとして保持し、この判断でアプリ実装段階へ進める。
