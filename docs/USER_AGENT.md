# User-Agent Viewer

参照：[Web版](https://maruyamamasaya.github.io/tool/user-agent-viewer/)。ブラウザ環境・端末情報の一覧、更新、User-Agentコピー、全情報コピーをネイティブUIへ移植。3テーマ・独立windowに対応。

## 取得元と制限

非永続の内蔵WKWebViewでローカルHTMLのみ実行し、navigator/screen/Intlを読む。SafariやChromeの稼働環境とは異なる。UAのブラウザ/OS/端末種別は文字列から推定。WebKitだけのUAをSafariと呼ばない。互換性用OS表記と実際のOSは別項目。

画面サイズ・ViewportはCSS px。Viewportは背景に配置した内蔵WebKitのサイズ。リサイズ後は更新する。言語・タイムゾーン・DPR・Cookie対応・接続状態・CPU論理コア・メモリ・最大タッチ点数も表示。未公開の値は取得不可。Cookie対応は保存成功の確認ではなく、Onlineも外部疎通の確認ではない。

外部UAの貼付解析は64KiBまで。ブラウザ・OS・デバイス種別のみ推定し、現在の端末情報と混ぜない。iPadのデスクトップUA・偽装・未知UAは正確に判定できない場合がある。任意のUAをコードとして実行しない。

入力・取得情報はメモリ内のみ。コピーは明示操作時のみ、通信・自動保存なし。
