# アクセシビリティ再許可の反復への対応

## Request / Investigation
ウィンドウ配置の許可要求が反復。AGENTS／CURRENT、CODEMAP／構成、運用、検証、ビルド生成器・検証器・起動処理を確認。インストール済みはad hoc、識別条件はcdhash。通常sandbox内では署名identityが0件だったが、通常権限の読取では既存Apple Development証明書3件と単一の/Applications起動プロセスを確認。

## Changes
- 既存の本人名義のApple Development証明書をローカルxcconfigで固定。Debug／Release・再生成で保持。秘密鍵の書き出し・新規証明書作成・信頼設定変更なし。
- Fullで証明書署名からad hocへの逆戻りを拒否。拒否／許容のテスト追加。
- AppDelegateのToolWindowsをlazy化。通常起動だけで初期化し、--login-statusなどの別プロセスがホットキー競合から保存設定をOFFにする経路を除去。
- 署名運用と判断0010を文書化。

## Validation / Result
- Fast／Full成功、Swift単体152件、検証器6件、Python構文、diffチェック。
- 異なる内容の実行ファイル2本を同じ証明書で署名、識別条件一致と更新前条件での検証成功。MyToolBoxも同条件で検証成功。検証用バイナリは起動せず一時フォルダを削除。
- --login-statusにショートカットONの一時引数を与えても保存値が変わらないことを実プロセスで確認。
- /Applicationsへ更新・正常終了／再起動。署名・全ファイル一致、loginStatus=1、旧版削除。PID 17550の起動先を確認。
- 実画面でショートカットON保持と、初回署名切替後の「許可が必要」を確認。

## Remaining Issues
ユーザーの新署名に対する再許可待ち。許可維持の実機確認は未完了。署名の安定性検証だけでTCC維持を成功とは扱わない。証明書の期限切れ／更新時も別途確認する。
