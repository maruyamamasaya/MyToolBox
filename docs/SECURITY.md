# セキュリティ状態の確認

macOS 14+のモニター一覧から「セキュリティ」を開く。名称・文字／アイコン／色による状態・保護内容・項目別の最終確認日時・失敗理由を表示。「再確認」で更新中は全項目を確認中へ切替、ボタンを無効化する。起動時／未取得画面表示時／手動だけ確認し、ポーリングしない。値はメモリ内のみ、既存の定期ログには追加しない。

## 取得方法と根拠

| 項目 | 実行ファイルと引数 | 表示範囲 |
| --- | --- | --- |
| ファイアウォール | `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate` | Application Firewallの全体状態。pfや個別アプリの許可設定は対象外 |
| FileVault | `/usr/bin/fdesetup status` | 起動ボリュームのFileVault。暗号化中／復号中は別状態、未知の応答は確認不可 |
| Gatekeeper | `/usr/sbin/spctl --status` | assessment subsystemの有効状態。個別アプリの安全性は判定しない |

- [Apple Xcode Help](https://help.apple.com/xcode/mac/current/en.lproj/dev9b7736b0e.html)は`spctl --status`とenabled/disabled応答を記載。同ページの変更用コマンドは実行しない。現行macOS同梱`man spctl`ではmacOS 15以降の変更操作廃止と、読取`--status`を区別している。
- [Appleのファイアウォール説明](https://support.apple.com/guide/mac-help/block-connections-to-your-mac-with-a-firewall-mh34041/mac)。取得フラグはApple提供の同梱`man socketfilterfw`で確認。
- [AppleのFileVault管理資料](https://support.apple.com/guide/deployment/manage-filevault-with-device-management-dep0a2cb7686/web)。同梱`man fdesetup`でstatus・非rootで実行できる状態コマンド・終了コード0/1/2を確認。`-extended`はAPFSで継続更新になるため使わない。Apple Siliconのストレージ暗号化とFileVaultの認証保護を混同しない。

通常権限で実行し、権限拒否は「確認できない」と表示。特権取得や設定変更、ネットワーク送信は行わない。固定パス／引数をProcessで直接実行、Cロケール、標準入力なし、stdout/stderr分離、各5秒timeout。専用actorがUIスレッド外で直列実行、MonitorStoreが重複要求を抑制。timeout時は自身の子プロセスだけを終了する。一時出力は権限制限付き専用ディレクトリに置き、取得後削除。OS更新で出力が変化した場合は誤判定せず、未対応／想定外として扱う。

## 検証と制約

SecurityTestsは既知応答・移行中・非zero終了・権限拒否・未知応答・stderr・timeout・起動失敗を検証。セキュリティ設定は変更しない。実機OS以外のmacOS 14/15、暗号化／復号の途中、非管理者アカウント全組合せは未確認。OSコマンドの応答形式は将来変更の可能性がある。

2026-10-16通常起動の実機確認：/Applications版でFirewall無効・FileVault有効・Gatekeeper有効を表示。再確認2回で項目別日時更新、戻る／再表示でキャッシュ維持、既存監視の継続を確認。開発制限環境のFileVault終了15は通常実行では再現せず、同じ読取コマンドも終了0・On。処理が短いため実機UIの確認中／無効ボタンの瞬間は捕捉できず、前述のモデル検証と区別する。
