# 比較ツールの統合とローカルGit管理
Status: Accepted / Date: 2026-10-15

## Context
ユーザーがdiff-viewerとlist-compareの追加、およびMyToolBox本体のGit管理を承認した。原本Webツールは既に別のGitHubリポジトリで管理されている。

## Decision
比較を1アイコン・2モードに統合する。テキスト差分は上限を超えた部分比較を行わずエラーにする。ネイティブ実装を独立して作る。MyToolBoxにmainブランチを初期化し、追加前スナップショットと今回変更を別コミットに保存する。

## Reason
共通する左右入力を再利用でき、一覧の過密化を抑える。切捨てによる誤認を防ぐ。Gitで追加前に戻せる履歴を確保する。

## Alternatives
2つの独立アイコン、元Webページの埋込、行数切捨て。GitHubへの即時公開は依頼範囲に含めない。

## Consequences
生成.appとキャッシュ・実行ログはGit対象外。新規checkoutはFull verifyでアプリを生成する。リモートは設定せず、Web原本とは別の履歴を持つ。
