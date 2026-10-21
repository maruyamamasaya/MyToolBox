# User-Agent Viewerの見やすさ改善

- 利用者が最も見づらいツールとして改善を依頼し、主要情報→UA全文、詳細／外部UA解析をタブへ分ける案を了承。途中の中断後、状況確認を受けて再開。
- UserAgentViewを標準520×640pt（最小460×580pt）へ。「この端末」「詳しい情報」「別のUAを解析」を分離。概要はブラウザ・OS・端末を大きめの3行へ、全文UAとコピーを独立配置。詳細はカード群からラベル／値の行へ。
- 内蔵WebKitをSafariと誤認しない表示、実行中macOSとUA互換OS表記の区別、UA端末推定の明示を維持。取得中／失敗はUAや端末を仮値で補わない。OS概要は実ProcessInfoのバージョン。
- 既存の取得項目・更新・UA／全情報／解析結果コピー、64KiB制限、ローカルHTMLのみの取得と非永続WebKitを維持。検証注入用に自動ロードを抑制できるinitを追加し、既定は従来通りロードする。
- Fast・Full成功（Swift単体、Release、署名、55helper）。diff check成功。
- tools/RenderUserAgentRedesign.swiftは隔離UserDefaults・非表示実Viewで4テーマ×概要／詳細／外部UA／取得中／失敗／上限超過の24画面描画。実取得値と混同しない表示確認用サンプルを注入（OSは実ProcessInfo）。build/user-agent-redesign-previewのBlue Cosmos概要／解析、Windows 98詳細を目視確認。
- compile対象：VisualTheme、UserAgentInfo、AppTheme／Theme*.swift、UserAgentViewとプローブ。swiftc -parse-as-libraryを使用。
- 今回の実WebKit取得・実画面操作・タブ切替・クリップボードは未検証。本番未反映・未コミット。他の作業中変更は保持。
