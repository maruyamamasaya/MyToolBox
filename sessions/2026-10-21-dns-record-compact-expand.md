# DNSレコード作成の小窓・拡大

- 標準400×560、拡大1100×850。「拡大／小さく戻す」でタイプ・入力・作成済みレコードを保持して切替。
- ホスト名とTTLを横並び、MX優先度は該当時だけ表示。作成レコードとゾーン出力を一つの一覧に集約し、個別削除・全削除・ゾーン一括コピーを常設。
- 入力ヒント、追加後の値クリア、5種類の検証、1,000件上限、TXT分割／エスケープ、宛先絶対名の仕様を維持。NetworkBuildersの変更なし。
- Fast／Full成功（Release・署名・56 helper検証）。tools/RenderCompactDNSRecordBuilder.swiftで実Viewの4テーマ×5タイプ×小窓／拡大の40画面を描画、枠への収まりを確認。非表示ネイティブ窓のサイズ往復も確認。
- 実NetworkBuilders.recordで合成レコード5件を生成し、CNAMEとMXの絶対名／優先度も確認。外部通信なし。
- 描画：build/dns-compact-preview/。Blue CosmosのA／MXとWindows 98のTXT小窓を目視。
- 本番配置・再起動なし。入力・タイプ切替・追加削除・コピー・ヘルプの実機操作は未検証。
