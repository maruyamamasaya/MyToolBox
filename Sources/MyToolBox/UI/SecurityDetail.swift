import SwiftUI

struct SecurityDetail: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: MonitorStore
    private func color(_ state: SecurityState) -> Color {
        switch state {
        case .enabled: return theme.classic ? Color(hex: 0x008000) : .green
        case .disabled, .encrypting, .decrypting: return theme.classic ? Color(hex: 0x806000) : .orange
        case .unavailable, .checking: return .secondary
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("セキュリティ設定").font(.title2.bold())
                    Spacer()
                    if store.securityChecking { ProgressView().controlSize(.small) }
                    Button("再確認") { store.refreshSecurity() }
                        .buttonStyle(ThemeButtonStyle(plain: true)).disabled(store.securityChecking)
                }
                ForEach(store.securityReadings, id: \.item) { reading in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reading.item.title).font(.headline)
                        Label(reading.state.rawValue, systemImage: reading.state.symbol)
                            .foregroundStyle(color(reading.state)).font(.body.weight(.semibold))
                        Text(reading.item.explanation).font(theme.font(12))
                        if !reading.reason.isEmpty { Text(reading.reason).font(theme.font(11)).foregroundStyle(.secondary).textSelection(.enabled) }
                        if let date = reading.checkedAt {
                            Text("最終確認：" + date.formatted(date: .abbreviated, time: .standard)).font(theme.font(10)).foregroundStyle(.secondary)
                        } else { Text("最終確認：未取得").font(theme.font(10)).foregroundStyle(.secondary) }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 12)).classicBevel()
                }
                Text("起動時と再確認時のみ取得します。設定変更・総合的な安全判定は行いません。").font(theme.font(11)).foregroundStyle(.secondary)
            }.padding(14)
        }.onAppear { store.refreshSecurityIfNeeded() }
    }
}
