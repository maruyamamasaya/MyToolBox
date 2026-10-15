import SwiftUI

struct NetworkReferenceView: View {
    let ports: Bool
    @State private var query = ""
    @State private var transport = "all"
    @State private var category = 0
    @State private var copyStatus = ""
    private var portResults: [PortReference] { PortReference.search(query, transport: transport) }
    private var statusResults: [HTTPStatusReference] { HTTPStatusReference.search(query, category: category) }
    var body: some View {
        ToolPage(ports ? "ポート番号検索" : "HTTPステータス一覧",
                 subtitle: ports ? "ポート番号とサービス名を、どちらからでも検索。" : "コード・名前・日本語の説明から意味を確認。",
                 symbol: ports ? "network" : "number.square", tint: .cyan) {
            VStack(alignment: .leading, spacing: 16) {
                ToolCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TextField(ports ? "例: 443、HTTPS、database" : "例: 404、Not Found、認証", text: $query)
                                .textFieldStyle(.roundedBorder).accessibilityLabel(ports ? "ポート番号・サービス名・用途で検索" : "HTTPコード・名前・説明で検索")
                            Button("クリア") { query = "" }.disabled(query.isEmpty)
                        }
                        if ports {
                            Picker("プロトコル", selection: $transport) {
                                Text("すべて").tag("all"); Text("TCP").tag("TCP"); Text("UDP").tag("UDP")
                            }.pickerStyle(.segmented)
                        } else {
                            Picker("分類", selection: $category) {
                                Text("すべて").tag(0)
                                ForEach(1...5, id: \.self) { value in Text("\(value)xx · \(HTTPStatusReference.categoryNames[value] ?? "")").tag(value) }
                            }.pickerStyle(.menu)
                        }
                    }
                }
                if ports {
                    Text("よく使うポート").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], alignment: .leading) {
                        ForEach(PortReference.popular, id: \.self) { port in
                            Button {
                                query = String(port); transport = "all"
                            } label: {
                                Text("\(port) · \(PortReference.all.first { $0.port == port }?.service ?? "")").lineLimit(1)
                            }.help("\(port)を検索")
                        }
                    }
                }
                HStack {
                    Text("検索結果 \(ports ? portResults.count : statusResults.count)件").font(.headline)
                    Spacer()
                    Text(copyStatus).font(.caption).foregroundStyle(.secondary)
                }
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if ports {
                            ForEach(portResults) { item in
                                row(number: item.port, badge: item.transport, name: item.service, summary: item.summary, tint: .cyan)
                            }
                        } else {
                            ForEach(statusResults) { item in
                                row(number: item.code, badge: item.categoryName, name: item.name, summary: item.summary, tint: categoryColor(item.category))
                            }
                        }
                        if ports ? portResults.isEmpty : statusResults.isEmpty {
                            Text("該当する項目がありません。検索語や絞り込みを変えてください。")
                                .foregroundStyle(.secondary).padding(30)
                        }
                    }
                }
                ToolFootnote(text: ports ? "主なサービスの一般的な既定値です。実際の設定によって異なります。" : "主なHTTPステータスを掲載しています。仕様や実装により扱いが異なる場合があります。")
            }.padding(24)
        }.frame(minWidth: 820, minHeight: 680)
    }
    private func row(number: Int, badge: String, name: String, summary: String, tint: Color) -> some View {
        ToolCard {
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(String(number)).font(.system(size: 27, weight: .bold, design: .monospaced)).foregroundStyle(tint)
                    Text(badge).font(.caption).foregroundStyle(.secondary)
                }.frame(width: 135)
                VStack(alignment: .leading, spacing: 6) {
                    Text(name).font(.headline)
                    Text(summary).font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                Menu {
                    Button("番号をコピー") { copy(String(number)) }
                    Button("説明ごとコピー") { copy("\(number) \(name) [\(badge)]\n\(summary)") }
                } label: { Image(systemName: "doc.on.doc") }.accessibilityLabel("\(number)のコピー")
            }
        }
    }
    private func categoryColor(_ value: Int) -> Color {
        switch value { case 1: return .blue; case 2: return .green; case 3: return .orange; case 4: return .red; default: return .purple }
    }
    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        copyStatus = NSPasteboard.general.setString(value, forType: .string) ? "コピーしました" : "コピーできませんでした"
    }
}
