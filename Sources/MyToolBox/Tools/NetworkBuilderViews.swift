import SwiftUI

struct CIDRAnalyzerView: View {
    @State private var input = "192.168.1.10/24\n192.168.1.11/24\n192.168.1.13/20"
    @State private var analysis: Result<NetworkBuilders.Analysis, Error>?
    @State private var source = ""
    @State private var formatted = ""
    @State private var formatError = ""
    @State private var expanded: Bool
    @State private var tab: Int
    @State private var resultTab: Int
    @State private var selectedSubnet = 0
    @State private var showsHelp = false
    @State private var status = ""
    init(initiallyExpanded: Bool = false, initialTab: Int = 0, initialResultTab: Int = 0,
         initialInput: String = "192.168.1.10/24\n192.168.1.11/24\n192.168.1.13/20", initiallyAnalyzed: Bool = false, initialSource: String = "", initiallyFormatted: Bool = false) {
        _expanded = State(initialValue: initiallyExpanded); _tab = State(initialValue: initialTab)
        _resultTab = State(initialValue: initialResultTab); _input = State(initialValue: initialInput)
        _source = State(initialValue: initialSource)
        if initiallyFormatted && initialSource.utf8.count <= 100_000 { _formatted = State(initialValue: NetworkBuilders.formatCIDR(initialSource)) }
        if initiallyAnalyzed { _analysis = State(initialValue: Result { try NetworkBuilders.analyze(initialInput) }) }
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("CIDR解析", systemImage: "network").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            Picker("表示", selection: $tab) { Text("解析").tag(0); Text("入力を整える").tag(1) }.pickerStyle(.segmented)
            if tab == 0 { analysisPanel } else { formattingPanel }
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading) }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 420, height: 600)))
            .frame(minWidth: expanded ? 800 : 400, idealWidth: expanded ? 1100 : 420,
                   minHeight: expanded ? 600 : 540, idealHeight: expanded ? 850 : 600)
            .onChange(of: input) { _, _ in analysis = nil; selectedSubnet = 0; status = "" }
    }
    private var analysisPanel: some View {
        VStack(spacing: 8) {
            TextEditor(text: $input).font(.system(.body, design: .monospaced)).frame(height: expanded ? 180 : 100).accessibilityLabel("解析するIPv4/CIDR")
            HStack {
                Button("解析する") { analysis = Result { try NetworkBuilders.analyze(input) }; selectedSubnet = 0; status = "" }
                Button("整形") { input = NetworkBuilders.formatCIDR(input); analysis = nil }
                Button { input = ""; analysis = nil } label: { Image(systemName: "trash").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("解析入力をクリア")
                Spacer()
                helpButton
            }
            if let analysis {
                switch analysis {
                case .failure(let error):
                    ScrollView { Text(error.localizedDescription).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading) }
                case .success(let result):
                    HStack { Text("成功 \(result.subnets.count)件 ／ エラー \(result.errors.count)件").font(.caption); Spacer() }
                    Picker("解析結果", selection: $resultTab) {
                        Text("詳細").tag(0); Text("グループ").tag(1); Text("包含関係").tag(2)
                    }.pickerStyle(.segmented)
                    if resultTab == 0, !expanded, !result.subnets.isEmpty {
                        Picker("入力", selection: $selectedSubnet) {
                            ForEach(result.subnets.indices, id: \.self) { index in Text("\(index + 1). " + result.subnets[index].input).tag(index) }
                        }
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if !result.errors.isEmpty { Text(result.errors.joined(separator: "\n")).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
                            if resultTab == 0 {
                                if expanded {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), alignment: .top)], alignment: .leading, spacing: 10) {
                                        ForEach(result.subnets.indices, id: \.self) { index in subnetDetails(result.subnets[index]) }
                                    }
                                } else if result.subnets.indices.contains(selectedSubnet) { subnetDetails(result.subnets[selectedSubnet]) }
                                if result.subnets.isEmpty { Text("解析できるIPv4/CIDRがありません。").foregroundStyle(.secondary) }
                            } else if resultTab == 1 {
                                Text(result.groups.isEmpty ? "該当なし" : result.groups.joined(separator: "\n")).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            } else {
                                Text(result.hierarchy.isEmpty ? "該当なし" : result.hierarchy).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            }
                        }.padding(2).frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    HStack {
                        Button("結果をコピー", systemImage: "doc.on.doc") {
                            if resultTab == 1 { copy(result.groups.joined(separator: "\n")) }
                            else if resultTab == 2 { copy(result.hierarchy) }
                            else {
                                let items = expanded ? result.subnets : result.subnets.indices.contains(selectedSubnet) ? [result.subnets[selectedSubnet]] : []
                                copy(items.map { $0.rows.map { $0.0 + ": " + $0.1 }.joined(separator: "\n") }.joined(separator: "\n\n"))
                            }
                        }.disabled(result.subnets.isEmpty)
                        Spacer()
                    }
                }
            } else {
                Text("IPv4/CIDRを1行1件入力して解析してください。").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    private func subnetDetails(_ subnet: NetworkBuilders.Subnet) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(subnet.rows.indices, id: \.self) { index in
                let row = subnet.rows[index]
                HStack(alignment: .top, spacing: 8) {
                    Text(row.0).font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(row.1).font(.system(.caption, design: .monospaced)).textSelection(.enabled).multilineTextAlignment(.trailing)
                    Button { copy(row.1) } label: { Image(systemName: "doc.on.doc").frame(width: 20, height: 20).contentShape(Rectangle()) }.accessibilityLabel(row.0 + "をコピー")
                }
            }
        }.padding(8).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
    }
    private var formattingPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("整形専用の入力（解析欄とは独立）").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $source).font(.system(.body, design: .monospaced)).frame(height: expanded ? 180 : 120).accessibilityLabel("整形するIPv4/CIDR")
            HStack {
                Button("整形する") {
                    if source.utf8.count > 100_000 { formatError = "入力は100KB以内にしてください。"; formatted = "" }
                    else { formatted = NetworkBuilders.formatCIDR(source); formatError = "" }
                    status = ""
                }
                Spacer()
                helpButton
            }
            if !formatError.isEmpty { Text(formatError).font(.caption).foregroundStyle(.red) }
            Text("整形結果 \(formatted.components(separatedBy: .newlines).filter { !$0.isEmpty }.count)件").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                Text(formatted.isEmpty ? "整形結果がここに表示されます。" : formatted).font(.system(.body, design: .monospaced)).textSelection(.enabled).padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            HStack {
                Button("コピー", systemImage: "doc.on.doc") { copy(formatted) }.disabled(formatted.isEmpty || !formatError.isEmpty)
                Button("解析欄へ送る") { input = formatted; analysis = nil; tab = 0 }.disabled(formatted.isEmpty || !formatError.isEmpty)
                Spacer()
            }
        }.onChange(of: source) { _, _ in formatted = ""; formatError = ""; status = "" }
    }
    private var helpButton: some View {
        Button { showsHelp.toggle() } label: { Image(systemName: "questionmark.circle").frame(width: 24, height: 24).contentShape(Rectangle()) }
            .accessibilityLabel("CIDR解析の使い方").popover(isPresented: $showsHelp) {
                Text("IPv4専用・最大1,000行／100KB。/31はポイントツーポイントの2ホスト、/32は1ホスト。/31・/32に通常のブロードキャスト用途はなく、欄には範囲の最終アドレスを表示します。入力の整形は全角スラッシュ・空白にも対応。")
                    .font(.caption).padding(16).frame(width: 310)
            }
    }
    private func copy(_ text: String) {
        NSPasteboard.general.clearContents(); status = NSPasteboard.general.setString(text, forType: .string) ? "コピーしました" : "コピーできませんでした"
    }
}
struct DNSRecordBuilderView: View {
    @State private var type = "A"
    @State private var host = "@"
    @State private var ttl = "3600"
    @State private var value = "192.0.2.1"
    @State private var priority = "10"
    @State private var records: [String] = []
    @State private var error: String?
    private var valueLabel: String {
        switch type { case "A": return "IPv4アドレス"; case "AAAA": return "IPv6アドレス"; case "CNAME": return "参照先ホスト名"; case "MX": return "メールサーバー"; default: return "テキスト" }
    }
    private var valueHint: String {
        switch type { case "A": return "例: 192.0.2.1"; case "AAAA": return "例: 2001:db8::1"; case "CNAME": return "例: example.com."; case "MX": return "例: mail.example.com."; default: return "引用符は自動付加。例: v=spf1 include:example.com ~all" }
    }
    @State private var expanded: Bool
    @State private var showsHelp = false
    @State private var status = ""
    init(initiallyExpanded: Bool = false, initialType: String = "A", initialValue: String = "192.0.2.1", initialRecords: [String] = []) {
        _expanded = State(initialValue: initiallyExpanded); _type = State(initialValue: initialType)
        _value = State(initialValue: initialValue); _records = State(initialValue: initialRecords)
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("DNSレコード作成", systemImage: "server.rack").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            Picker("タイプ", selection: $type) {
                ForEach(NetworkBuilders.recordTypes, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).onChange(of: type) { _, _ in value = ""; error = nil; status = "" }
            HStack {
                field("ホスト名", text: $host)
                field("TTL（秒）", text: $ttl)
            }
            field(valueLabel, text: $value)
            Text(valueHint).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            if type == "MX" { field("優先度", text: $priority) }
            HStack {
                Button("レコードを追加", systemImage: "plus", action: addRecord).disabled(records.count >= 1000)
                Spacer()
                Text("\(records.count)/1,000件").font(.caption).foregroundStyle(.secondary)
                Button { records = []; status = "" } label: {
                    Image(systemName: "trash").frame(width: 24, height: 24).contentShape(Rectangle())
                }.accessibilityLabel("すべてのレコードを削除").disabled(records.isEmpty)
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading) }
            Text("ゾーン出力").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(records.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Text(records[index]).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                            Button { records.remove(at: index); status = "" } label: {
                                Image(systemName: "xmark").frame(width: 24, height: 24).contentShape(Rectangle())
                            }.accessibilityLabel("レコード\(index + 1)を削除")
                        }.padding(8).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    }
                    if records.isEmpty { Text("上のフォームからレコードを追加してください。").font(.caption).foregroundStyle(.secondary).padding(8) }
                }.padding(2).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack {
                Button("ゾーンをコピー", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    status = NSPasteboard.general.setString(records.joined(separator: "\n"), forType: .string) ? "コピーしました" : "コピーできませんでした"
                }.disabled(records.isEmpty)
                Spacer()
                Button { showsHelp.toggle() } label: {
                    Image(systemName: "questionmark.circle").frame(width: 24, height: 24).contentShape(Rectangle())
                }.accessibilityLabel("DNSレコードの作成方法").popover(isPresented: $showsHelp) {
                    Text("@はゾーンのルート。CNAME/MXの宛先は末尾に.を付け絶対名で出力。TXTは引用符・バックスラッシュをエスケープし255バイト以下に分割します。TTLは0〜2147483647、MX優先度は0〜65535。DNSへの登録・問い合わせは行いません。レコード間のCNAME競合などは登録先で確認してください。")
                        .font(.caption).padding(16).frame(width: 310)
                }
            }
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 400, height: 560)))
            .frame(minWidth: expanded ? 800 : 380, idealWidth: expanded ? 1100 : 400,
                   minHeight: expanded ? 600 : 520, idealHeight: expanded ? 850 : 560)
    }
    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: text).textFieldStyle(.roundedBorder).accessibilityLabel(title)
        }
    }
    private func addRecord() {
        do {
            guard records.count < 1000 else { throw NetworkBuilders.Failure.invalid("レコードは1,000件までです。") }
            records.append(try NetworkBuilders.record(type: type, host: host, ttl: ttl, value: value, priority: priority))
            value = ""; error = nil; status = ""
        } catch { self.error = error.localizedDescription }
    }
}
