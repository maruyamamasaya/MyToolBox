import SwiftUI

struct CIDRAnalyzerView: View {
    @State private var input = "192.168.1.10/24\n192.168.1.11/24\n192.168.1.13/20"
    @State private var analysis: Result<NetworkBuilders.Analysis, Error>?
    var body: some View {
        ToolPage("CIDR解析", subtitle: "複数IPv4の範囲・グループ・包含関係", symbol: "network", tint: .cyan) {
            ScrollView { VStack(alignment: .leading, spacing: 18) {
                ToolCard { VStack(alignment: .leading, spacing: 12) {
                    Text("IPv4/CIDRを1行1件（最大1,000行）")
                    TextEditor(text: $input).font(.system(.body, design: .monospaced)).frame(height: 180).onChange(of: input) { _, _ in analysis = nil }
                    HStack {
                        Button("空白・スラッシュを整形") { input = NetworkBuilders.formatCIDR(input) }
                        Button("解析する") { analysis = Result { try NetworkBuilders.analyze(input) } }
                        Button("クリア") { input = ""; analysis = nil }
                    }
                } }
                if let analysis {
                    switch analysis {
                    case .failure(let error): Text(error.localizedDescription).foregroundStyle(.red)
                    case .success(let result):
                        Text("成功 \(result.subnets.count)件 ／ エラー \(result.errors.count)件")
                        if !result.errors.isEmpty { Text(result.errors.joined(separator: "\n")).foregroundStyle(.red).textSelection(.enabled) }
                        ForEach(result.subnets.indices, id: \.self) { i in UtilityResult(result: .success(result.subnets[i].rows)) }
                        UtilityResult(result: .success([("ネットワーク一覧", result.groups.joined(separator: "\n")), ("包含関係（直属）", result.relations.isEmpty ? "該当なし" : result.relations.joined(separator: "\n"))]))
                    }
                }
                ToolFootnote(text: "/31はポイントツーポイントの2ホスト、/32は1ホストとして表示。/31・/32に通常のブロードキャスト用途はなく、欄には範囲の最終アドレスを表示します。IPv6には対応していません。")
            }.padding(24) }
        }.frame(minWidth: 850, minHeight: 740)
    }
}
struct DNSRecordBuilderView: View {
    @State private var type = "A", host = "@", ttl = "3600", value = "192.0.2.1", priority = "10"
    @State private var records: [String] = []
    @State private var error: String?
    var body: some View {
        ToolPage("DNSレコード作成", subtitle: "A・AAAA・CNAME・MX・TXTをゾーン形式へ", symbol: "server.rack", tint: .cyan) {
            ScrollView { VStack(alignment: .leading, spacing: 18) {
                ToolCard { VStack(alignment: .leading, spacing: 14) {
                    ThemePicker("タイプ", selection: $type, options: NetworkBuilders.recordTypes.map { ($0, $0) }, tabs: true)
                    UtilityField(title: "ホスト名", text: $host)
                    UtilityField(title: "TTL（秒）", text: $ttl)
                    UtilityField(title: type == "TXT" ? "テキスト" : "アドレス／宛先", text: $value)
                    if type == "MX" { UtilityField(title: "優先度", text: $priority) }
                    if let error { Text(error).foregroundStyle(.red) }
                    Button("レコードを追加") {
                        do {
                            guard records.count < 1000 else { throw NetworkBuilders.Failure.invalid("レコードは1,000件までです。") }
                            records.append(try NetworkBuilders.record(type: type, host: host, ttl: ttl, value: value, priority: priority)); error = nil
                        } catch { self.error = error.localizedDescription }
                    }
                } }
                ToolCard { VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("作成したレコード \(records.count)件"); Spacer(); Button("すべて削除") { records = [] } }
                    ForEach(records.indices, id: \.self) { i in
                        HStack { Text(records[i]).font(.system(.body, design: .monospaced)).textSelection(.enabled); Spacer(); Button("削除") { records.remove(at: i) } }
                    }
                } }
                if !records.isEmpty { UtilityResult(result: .success([("ゾーン出力", records.joined(separator: "\n"))])) }
                ToolFootnote(text: "@はゾーンのルート。CNAME/MXの宛先は末尾に.を付け絶対名で出力。TXTは引用符・バックスラッシュをエスケープし255バイト以下に分割します。DNSへの登録・問い合わせは行いません。レコード間のCNAME競合などは登録先で確認してください。")
            }.padding(24) }
        }.frame(minWidth: 850, minHeight: 720)
    }
}
