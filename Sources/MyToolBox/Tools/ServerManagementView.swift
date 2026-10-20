import SwiftUI

@MainActor final class ServerManagementModel: ObservableObject {
    @Published var rows: [ServerCheckReading] = []
    @Published var busy = false
    private let collector = ServerManagementCollector()
    func refresh() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let result = await collector.read()
        guard !Task.isCancelled else { return }
        rows = result
    }
}

struct ServerManagementView: View {
    @StateObject private var model: ServerManagementModel
    @MainActor init(model: ServerManagementModel? = nil) {
        _model = StateObject(wrappedValue: model ?? ServerManagementModel())
    }
    var body: some View {
        ToolPage("サーバー管理", subtitle: "この Mac の写真サーバーと VPN 接続を確認", symbol: "server.rack", tint: .cyan, usesNetwork: true) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ToolCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button(model.busy ? "確認中…" : "状態を更新") { Task { await model.refresh() } }.disabled(model.busy)
                                if model.busy { ProgressView().controlSize(.small) }
                            }
                            Text("対象：この Mac の baby-media-web（凛紬花ちゃんの共有サーバー）")
                            Text("画面表示時と手動更新時のみ取得。各確認は最大5秒。更新中は前回の結果を表示します。").font(.caption)
                            Text("HTTP 応答・待受・launchd・VPN 設定を個別に確認します。外出先からの接続やログイン、画像表示の成功を保証するものではありません。").font(.caption)
                        }
                    }
                    if model.rows.isEmpty { Text(model.busy ? "状態を取得しています…" : "未確認") }
                    ForEach(model.rows) { row in
                        ToolCard {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(row.item.title).font(.headline)
                                    Spacer()
                                    Label(row.state.rawValue, systemImage: row.state == .confirmed ? "checkmark.circle" : "questionmark.circle")
                                        .foregroundStyle(row.state == .confirmed ? Color.green : Color.orange)
                                }
                                Text(row.detail).textSelection(.enabled)
                                Text("最終確認：\(row.checkedAt.formatted(date: .numeric, time: .standard))").font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }.padding(20)
            }
        }.frame(minWidth: 760, idealWidth: 900, minHeight: 560, idealHeight: 760).task { if model.rows.isEmpty { await model.refresh() } }
    }
}
