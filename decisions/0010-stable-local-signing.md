# 更新時のプライバシー許可に備えて署名を固定する
Status: Accepted / Date: 2026-10-16

## Context
ウィンドウマネージャーの許可再要求が反復。配置済みアプリはad hoc署名で、識別条件が実行ファイルのcdhashに固定されていた。ほかのツール追加でもMyToolBox全体が更新される。

## Decision
このMacに既存のApple Development証明書を使用。共通xcconfigからGit除外のローカル選択を読み込み、Debug／Releaseとプロジェクト再生成で維持する。標準Fullは証明書署名からad hocへの逆戻りを拒否する。

## Reason / Alternatives
同じ証明書とbundle IDの識別条件を更新前後で維持する。単なる許可の再設定を恒常対応にしない。新規証明書、信頼ルート追加、TCCデータ変更、識別条件の緩和は行わない。Developer ID配布・公証は別課題。

## Consequences
初回の署名方式変更後にはユーザーの再許可が必要になり得る。証明書更新・期限切れ時は再検証。fresh checkoutではローカル設定を復元する。コード識別条件の検証と、実機の権限維持確認を区別する。[運用](../docs/CODE_SIGNING.md)。
