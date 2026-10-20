import SwiftUI

struct NetworkReferenceView: View {
    let ports: Bool
    var body: some View {
        if ports { CompactPortReferenceView() }
        else { CompactHTTPStatusView() }
    }
}

struct CompactPortReferenceView: View {
    @State private var query: String
    @State private var transport: String
    @State private var copyStatus = ""
    @State private var showsSettings = false
    init(query: String = "", transport: String = "all") {
        _query = State(initialValue: query); _transport = State(initialValue: transport)
    }
    private var results: [PortReference] { PortReference.search(query, transport: transport) }
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("ポート検索").font(.headline)
                Spacer(minLength: 0)
                Menu("よく使う") {
                    ForEach(PortReference.popular, id: \.self) { port in
                        Button("\(port) · \(PortReference.all.first { $0.port == port }?.service ?? "")") {
                            query = String(port); transport = "all"
                        }
                    }
                }.fixedSize().accessibilityLabel("よく使うポート")
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("ポート検索の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            ThemeMenu()
                            Text("主なサービスの一般的な既定値です。実際の設定によって異なります。番号は完全一致、サービス名・用途は部分一致で検索します。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            HStack(spacing: 8) {
                TextField("443・HTTPS・用途", text: $query).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("ポート番号・サービス名・用途で検索")
                Button { query = "" } label: {
                    Image(systemName: "xmark").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("検索をクリア").disabled(query.isEmpty)
            }
            Picker("プロトコル", selection: $transport) {
                Text("すべて").tag("all"); Text("TCP").tag("TCP"); Text("UDP").tag("UDP")
            }.pickerStyle(.segmented).labelsHidden()
            HStack {
                Text("\(results.count)件").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(copyStatus).font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if results.isEmpty {
                        Text("該当する項目がありません。検索語や絞り込みを変えてください。")
                            .font(.caption).foregroundStyle(.secondary).padding(.vertical, 16)
                    }
                    ForEach(results) { item in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(String(item.port)).font(.system(size: 20, weight: .semibold, design: .monospaced))
                                Text(item.transport).font(.caption2).foregroundStyle(.secondary)
                            }.frame(width: 64, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.service).font(.subheadline.weight(.semibold))
                                Text(item.summary).font(.caption).foregroundStyle(.secondary)
                            }.textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Menu {
                                Button("番号をコピー") { copy(String(item.port)) }
                                Button("説明ごとコピー") { copy("\(item.port) \(item.service) [\(item.transport)]\n\(item.summary)") }
                            } label: {
                                Image(systemName: "doc.on.doc").frame(width: 20, height: 28).contentShape(Rectangle())
                            }.menuStyle(.borderedButton).fixedSize().accessibilityLabel("\(item.port)のコピー")
                        }
                        Divider().opacity(0.4)
                    }
                }
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 300, idealWidth: 320, minHeight: 320, idealHeight: 360)
            .onChange(of: query) { _, _ in copyStatus = "" }
            .onChange(of: transport) { _, _ in copyStatus = "" }
    }
    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        copyStatus = NSPasteboard.general.setString(text, forType: .string) ? "コピーしました" : "コピーできませんでした"
    }
}


struct CompactHTTPStatusView: View {
    @State private var query: String
    @State private var category: Int
    @State private var copyStatus = ""
    @State private var showsSettings = false
    init(query: String = "", category: Int = 0) {
        _query = State(initialValue: query); _category = State(initialValue: category)
    }
    private var results: [HTTPStatusReference] { HTTPStatusReference.search(query, category: category) }
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("HTTPステータス").font(.headline)
                Spacer(minLength: 0)
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("HTTPステータスの設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            ThemeMenu()
                            Text("主なHTTPステータスを掲載しています。仕様や実装により扱いが異なる場合があります。コード・名前・日本語説明・分類から部分一致で検索します。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            HStack(spacing: 8) {
                TextField("404・Not Found・説明", text: $query).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("HTTPコード・名前・説明で検索")
                Button { query = "" } label: {
                    Image(systemName: "xmark").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("検索をクリア").disabled(query.isEmpty)
            }
            Picker("分類", selection: $category) {
                Text("すべて").tag(0)
                ForEach(1...5, id: \.self) { value in
                    Text("\(value)xx · \(HTTPStatusReference.categoryNames[value] ?? "")").tag(value)
                }
            }.pickerStyle(.menu)
            HStack {
                Text("\(results.count)件").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(copyStatus).font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if results.isEmpty {
                        Text("該当する項目がありません。検索語や絞り込みを変えてください。")
                            .font(.caption).foregroundStyle(.secondary).padding(.vertical, 16)
                    }
                    ForEach(results) { item in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(String(item.code)).font(.system(size: 20, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(categoryColor(item.category))
                                Text("\(item.category)xx").font(.caption2).foregroundStyle(.secondary)
                            }.frame(width: 64, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).font(.subheadline.weight(.semibold))
                                Text(item.summary).font(.caption).foregroundStyle(.secondary)
                            }.textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Menu {
                                Button("番号をコピー") { copy(String(item.code)) }
                                Button("説明ごとコピー") { copy("\(item.code) \(item.name) [\(item.categoryName)]\n\(item.summary)") }
                            } label: {
                                Image(systemName: "doc.on.doc").frame(width: 20, height: 28).contentShape(Rectangle())
                            }.menuStyle(.borderedButton).fixedSize().accessibilityLabel("\(item.code)のコピー")
                        }
                        Divider().opacity(0.4)
                    }
                }
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 300, idealWidth: 320, minHeight: 320, idealHeight: 360)
            .onChange(of: query) { _, _ in copyStatus = "" }
            .onChange(of: category) { _, _ in copyStatus = "" }
    }
    private func categoryColor(_ value: Int) -> Color {
        switch value { case 1: return .blue; case 2: return .green; case 3: return .orange; case 4: return .red; default: return .purple }
    }
    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        copyStatus = NSPasteboard.general.setString(text, forType: .string) ? "コピーしました" : "コピーできませんでした"
    }
}
