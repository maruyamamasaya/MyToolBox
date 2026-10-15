import SwiftUI
import Charts

struct Dashboard: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: MonitorStore
    var openTools: (() -> Void)? = nil
    private let titles = ["cpu": "CPU", "gpu": "GPU", "memory": "Memory", "network": "Network", "storage": "Storage", "battery": "Battery", "sensors": "Sensors"]
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if store.selected != "overview" {
                    Button { store.selected = "overview" } label: { Label("戻る", systemImage: "chevron.left") }
                        .buttonStyle(ThemeButtonStyle(plain: true))
                }
                Text(store.selected == "overview" ? "システムモニター" : store.selected == "settings" ? "設定" : titles[store.selected] ?? "詳細")
                    .font(.headline)
                Spacer()
                if let date = store.snapshot?.date { Text(date, style: .time).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            }.padding(14)
            Divider()
            if store.selected == "settings" { SettingsPanel(store: store) }
            else if store.selected == "overview" { overview }
            else { detail.id(store.selected) }
            Divider()
            HStack {
                if let openTools { Button(action: openTools) { Label("ツール一覧", systemImage: "square.grid.2x2") } }
                Button { store.selected = "settings"; store.refreshLoginStatus() } label: { Label("設定", systemImage: "gearshape") }
                Spacer()
                Text("監視はバックグラウンドで継続").font(theme.font(9)).foregroundStyle(.secondary)
            }.buttonStyle(ThemeButtonStyle(plain: true)).font(theme.font(11)).padding(12)
        }.frame(width: 390, height: 620)
    }
    private func metric(_ id: String, _ key: String) -> Metric {
        store.snapshot?.metric(id, key) ?? Metric(store.snapshot == nil ? .waiting : .unavailable, store.sleeping ? "スリープ中" : "取得待ち／未取得")
    }
    private func value(_ id: String, _ key: String) -> String {
        let m = metric(id, key)
        if let v = m.value, m.unit == "%" { return String(format: "%.0f%%", v) }
        return MetricFormat.string(m, preferences: store.preferences)
    }
    private func color(_ id: String) -> Color {
        switch store.alertLevels[id] ?? .normal {
        case .normal: return theme.classic ? Color(hex: 0x008000) : .green
        case .warning: return theme.classic ? Color(hex: 0x806000) : .yellow
        case .critical: return .red
        }
    }
    private func caption(_ text: String) -> some View {
        Text(text).font(theme.font(11)).foregroundStyle(.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
    }
    @ViewBuilder private func meter(_ id: String, _ key: String) -> some View {
        if let v = metric(id, key).value {
            ProgressView(value: min(100, max(0, v)), total: 100).tint(color(id))
        }
    }
    private func card<Content: View>(_ id: String, _ symbol: String, @ViewBuilder content: () -> Content) -> some View {
        Button { store.selected = id } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Label(titles[id] ?? id, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    if store.alertLevels[id] == .critical { Text("要確認").font(theme.font(10)).foregroundStyle(.red) }
                    else if store.alertLevels[id] == .warning { Text("注意").font(theme.font(10)).foregroundStyle(.yellow) }
                    Image(systemName: "chevron.right").font(theme.font( 8)).foregroundStyle(.tertiary)
                }
                content()
            }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 12))
                .classicBevel()
                .contentShape(RoundedRectangle(cornerRadius: theme.classic ? 0 : 12))
        }.buttonStyle(ThemeButtonStyle(plain: true)).accessibilityHint("クリックで詳細を表示")
    }
    private var overview: some View {
        ScrollView {
            VStack(spacing: 9) {
                HStack(alignment: .top, spacing: 9) {
                    usageCard("cpu", "cpu")
                    usageCard("gpu", "display")
                }
                HStack(alignment: .top, spacing: 9) {
                    card("memory", "memorychip") {
                        Text(value("memory", "使用率")).font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(color("memory"))
                        caption("残り \(value("memory", "利用可能容量（推定）")) · 推定")
                        historyChart("memory", miniature: true)
                    }
                    card("storage", "internaldrive") {
                        Text(value("storage", "空き容量")).font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(color("storage"))
                        caption("空き / \(value("storage", "総容量"))")
                        meter("storage", "使用率")
                        caption("容量バーは使用率")
                    }
                }
                card("network", "network") {
                    HStack {
                        Text("↓ " + value("network", "受信速度"))
                        Spacer()
                        Text("↑ " + value("network", "送信速度"))
                    }.font(theme.font( 15, weight: .semibold, design: .monospaced)).minimumScaleFactor(0.75).lineLimit(1)
                    historyChart("network", miniature: true)
                    caption(store.snapshot?.readings.first(where: { $0.id == "network" })?.notes.first ?? "接続情報を取得待ち")
                }
                card("battery", "battery.100percent") {
                    HStack {
                        Text(value("battery", "残量")).font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(color("battery"))
                        Spacer()
                        caption(batteryState)
                    }
                    meter("battery", "残量")
                }
                card("sensors", "fan") {
                    HStack {
                        caption("ファン1  \(value("sensors", "ファン1回転数"))")
                        Spacer()
                        caption("ファン2  \(value("sensors", "ファン2回転数"))")
                    }
                }
            }.padding(12)
        }
    }
    private var batteryState: String {
        if metric("battery", "充電中").value == 1 { return "⚡ 充電中" }
        if metric("battery", "電源接続").value == 1 { return "電源接続 · 充電なし" }
        if metric("battery", "電源接続").value == 0 { return "バッテリー駆動" }
        return "電源状態：取得不可"
    }
    private func usageCard(_ id: String, _ symbol: String) -> some View {
        card(id, symbol) {
            Text(value(id, "使用率")).font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(color(id))
            Text(value("sensors", id == "cpu" ? "CPU温度" : "GPU温度"))
                .font(.caption.monospacedDigit()).foregroundStyle(color(id == "cpu" ? "CPU温度" : "GPU温度"))
            historyChart(id, miniature: true)
        }
    }
    private func historyChart(_ id: String, miniature: Bool) -> some View {
        let keys = id == "network" ? ["network.受信速度", "network.送信速度"] : [id + ".使用率"]
        let last = store.history.points.last
        let end = last?.date ?? Date()
        let lastUptime = last?.uptime ?? 0
        return VStack(alignment: .leading, spacing: 2) {
            if !miniature { Text("直近60秒 · \(id == "network" ? "B/s" : "%")").font(theme.font(11)).foregroundStyle(.secondary) }
            Chart {
                ForEach(store.history.points) { point in
                    ForEach(keys, id: \.self) { key in
                        if let v = point.values[key] {
                            LineMark(x: .value("時刻", end.addingTimeInterval(point.uptime - lastUptime)), y: .value("値", v), series: .value("区間", "\(key)-\(point.segment)"))
                                .foregroundStyle(by: .value("指標", key == "network.受信速度" ? "受信" : key == "network.送信速度" ? "送信" : "使用率"))
                        }
                    }
                }
            }.chartXScale(domain: end.addingTimeInterval(-60)...end)
                .chartYScale(domain: .automatic(includesZero: true))
                .chartXAxis(miniature ? .hidden : .automatic)
                .chartYAxis(miniature ? .hidden : .automatic)
                .chartLegend(miniature ? .hidden : .automatic)
                .frame(height: miniature ? 18 : 145)
            if !miniature { caption("欠測は0に補完しません。時刻は単調時刻の経過秒を最新実時刻に対応付けます。") }
        }
    }
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(titles[store.selected] ?? "MyToolBox").font(.title2.bold())
                    Spacer()
                    if let date = store.snapshot?.date { Text(date, style: .time).foregroundStyle(.secondary).monospacedDigit() }
                }
                if ["cpu", "gpu", "memory", "network"].contains(store.selected) { historyChart(store.selected, miniature: false) }
                if let reading = store.snapshot?.readings.first(where: { $0.id == store.selected }) {
                    ForEach(reading.metrics.keys.sorted(), id: \.self) { name in
                        let metric = reading.metrics[name]!
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(name); Spacer(); Text(MetricFormat.string(metric, preferences: store.preferences)).font(.body.monospacedDigit()).foregroundStyle(metric.value == nil ? .secondary : .primary) }
                            if !metric.reason.isEmpty { Text(metric.reason).font(theme.font(11)).foregroundStyle(.secondary) }
                        }
                        Divider()
                    }
                    ForEach(reading.notes, id: \.self) { Text($0).font(theme.font(11)).foregroundStyle(.secondary).textSelection(.enabled) }
                    if ["battery", "sensors"].contains(reading.id) { Text("この項目は5秒周期。表示時刻より最大5秒前の取得値です。").font(theme.font(11)).foregroundStyle(.secondary) }
                } else { Text(store.sleeping ? "スリープ中：取得停止" : "初回サンプル待ち") }
            }.padding(14)
        }
    }

}
