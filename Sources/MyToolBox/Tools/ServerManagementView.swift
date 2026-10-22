import SwiftUI
import AppKit

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
    @State private var showsDiagnostics: Bool
    @State private var showsMusicDiagnostics: Bool
    private let refreshOnAppear: Bool
    @MainActor init(model: ServerManagementModel? = nil, initiallyShowsDiagnostics: Bool = false, initiallyShowsMusicDiagnostics: Bool = false, refreshOnAppear: Bool = true) {
        _model = StateObject(wrappedValue: model ?? ServerManagementModel())
        _showsDiagnostics = State(initialValue: initiallyShowsDiagnostics)
        _showsMusicDiagnostics = State(initialValue: initiallyShowsMusicDiagnostics)
        self.refreshOnAppear = refreshOnAppear
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "server.rack").font(.title2).foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text("サーバー管理").font(.title3.bold())
                    Text("このMacの写真・音楽・TaskApp中継").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                ThemeMenu()
                Button { Task { await model.refresh() } } label: {
                    Label(model.busy ? "確認中…" : "更新", systemImage: "arrow.clockwise")
                }.disabled(model.busy)
            }.padding(16)
            Divider()
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if geometry.size.width >= 680 {
                            HStack(alignment: .top, spacing: 14) { photoCard; musicCard }
                        } else {
                            photoCard; musicCard
                        }
                        serverCard(.taskRelayListener, title: "TaskApp 中継", app: "CalendarTaskApp · Dot ↔ iPhone", symbol: "calendar.badge.clock", port: "192.168.0.35:8778 · TLS", success: "待受あり",
                                   explanation: "タスクとDotのひとことを保存・配信する窓口です。ひとことの定期生成は含みません。")
                        ToolCard {
                            VStack(alignment: .leading, spacing: 10) {
                                diagnostic(.taskRelayLaunchd)
                                Text("ログイン時に起動し、終了後は最低30秒間隔で再試行します。スリープ中・ログイン前の稼働は保証されません。再ログイン・スリープ復帰は未検証です。")
                                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if model.busy {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text(model.rows.isEmpty ? "状態を確認しています…" : "更新中です。表示は前回の確認結果です。")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        ToolCard {
                            DisclosureGroup(isExpanded: $showsDiagnostics) {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach([ServerCheck.listener, .launchd, .tailscale, .serve]) { item in
                                        diagnostic(item)
                                    }
                                }.padding(.top, 14)
                            } label: {
                                Label("写真サーバーの詳しい診断", systemImage: "stethoscope").font(.subheadline.weight(.semibold))
                            }
                        }
                        ToolCard {
                            DisclosureGroup(isExpanded: $showsMusicDiagnostics) {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach([ServerCheck.musicListener, .musicLaunchd, .musicLocalListener]) { item in
                                        diagnostic(item)
                                    }
                                    Text("常駐はlaunchdの診断応答、配信は8768のPython待受、内部設定画面は8769のローカル待受を確認します。音楽再生・認証・別端末からの接続は未確認です。")
                                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                }.padding(.top, 14)
                            } label: {
                                Label("音楽サーバーの詳しい診断", systemImage: "stethoscope").font(.subheadline.weight(.semibold))
                            }
                        }
                        Text("画面を開いた時と更新時に確認します。接続できない場合も、停止とは断定しません。外出先からの接続・認証・写真表示・音楽再生は確認対象外です。")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }.padding(16)
                }
            }
        }.frame(minWidth: 440, idealWidth: 800, minHeight: 440, idealHeight: 540)
            .task { if refreshOnAppear && model.rows.isEmpty { await model.refresh() } }
    }
    private var photoCard: some View {
        serverCard(.health, title: "写真", app: "baby-media-web", symbol: "photo", port: "8080 · HTTP", success: "応答あり",
                   explanation: "このMacからHTTP応答を確認します。")
    }
    private var musicCard: some View {
        serverCard(.musicListener, title: "音楽", app: "MyMusic LAN Cardinal", symbol: "music.note", port: "8768 · TCP", success: "待受あり",
                   explanation: "Pythonの待受を確認します。再生成功の確認ではありません。")
    }
    private func reading(_ item: ServerCheck) -> ServerCheckReading? { model.rows.first { $0.item == item } }
    private func color(_ state: ServerCheckState?) -> Color {
        switch state { case .confirmed: return .green; case .attention: return .orange; default: return .secondary }
    }
    private func serverCard(_ item: ServerCheck, title: String, app: String, symbol: String, port: String, success: String, explanation: String) -> some View {
        let row = reading(item)
        return ToolCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: symbol).font(.title2).foregroundStyle(.cyan)
                        .frame(width: 40, height: 40).background(.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.headline)
                        Text(app).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                Label(row?.state == .confirmed ? success : row?.state.rawValue ?? (model.busy ? "確認中" : "未確認"),
                      systemImage: row?.state == .confirmed ? "checkmark.circle.fill" : "questionmark.circle")
                    .font(.title2.weight(.semibold)).foregroundStyle(color(row?.state))
                Text(port).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                Text(explanation).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).frame(minHeight: 34, alignment: .topLeading)
                Divider()
                Text(row?.detail ?? "まだ確認結果がありません。更新すると取得します。")
                    .font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                Text(row.map { "最終確認 " + $0.checkedAt.formatted(date: .numeric, time: .standard) } ?? "最終確認 —")
                    .font(.caption2).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func diagnostic(_ item: ServerCheck) -> some View {
        let row = reading(item)
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(item.title).font(.subheadline.weight(.semibold))
                Spacer()
                Label(row?.state.rawValue ?? "未確認", systemImage: row?.state == .confirmed ? "checkmark.circle" : "questionmark.circle")
                    .font(.caption).foregroundStyle(color(row?.state))
            }
            Text(row?.detail ?? "確認結果がありません").font(.caption).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            if let row { Text("最終確認 " + row.checkedAt.formatted(date: .numeric, time: .standard)).font(.caption2).foregroundStyle(.secondary) }
        }
    }
}


/// Owned by the main app only; independent tool windows never create menu timers.
@MainActor final class ServerMenuController: NSObject, NSMenuDelegate {
    private let collector = ServerManagementCollector()
    private var readings: [ServerCheckReading] = []
    private var busy = false
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var status: NSStatusItem?
    var openDetails: (() -> Void)?

    func start() {
        guard status == nil else { return }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu(); menu.autoenablesItems = false; menu.delegate = self; status?.menu = menu
        status?.button?.imagePosition = .imageLeading
        updatePresentation()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.readings = []; self?.refresh() }
        }
        refresh()
    }
    func stop() {
        timer?.invalidate(); timer = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        if let status { NSStatusBar.system.removeStatusItem(status) }
        status = nil
    }
    @objc func refresh() {
        updatePresentation()
        guard !busy else { return }
        busy = true; updatePresentation()
        Task { [weak self] in
            guard let self else { return }
            let result = await collector.read(menuOnly: true)
            readings = result; busy = false; updatePresentation()
        }
    }
    func menuWillOpen(_ menu: NSMenu) { updatePresentation() }
    @objc private func showDetails() { openDetails?() }
    private func updatePresentation() {
        guard let status, let menu = status.menu else { return }
        var descriptions: [String] = []
        menu.removeAllItems()
        for (item, name) in [(ServerCheck.health, "写真"), (.musicListener, "音楽"), (.taskRelayListener, "TaskApp中継")] {
            let state = ServerIndicator.state(for: item, readings: readings)
            let label = state == .confirmed ? (item == .health ? "HTTP応答あり" : "待受あり") : state?.rawValue ?? "未確認・期限切れ"
            descriptions.append(name + "：" + label)
            let title = NSMenuItem(title: name + "：" + label, action: nil, keyEquivalent: "")
            title.isEnabled = false; menu.addItem(title)
            if let row = readings.first(where: { $0.item == item }) {
                let detail = NSMenuItem(title: row.detail, action: nil, keyEquivalent: ""); detail.indentationLevel = 1; detail.isEnabled = false; menu.addItem(detail)
                let date = NSMenuItem(title: "確認：" + row.checkedAt.formatted(date: .omitted, time: .standard), action: nil, keyEquivalent: "")
                date.indentationLevel = 1; date.isEnabled = false; menu.addItem(date)
            }
        }
        status.button?.title = ""
        status.button?.image = ServerStatusImage.make(readings: readings)
        status.button?.toolTip = descriptions.joined(separator: "\n")
        status.button?.setAccessibilityLabel("サーバー状態 " + descriptions.joined(separator: "、"))
        menu.addItem(.separator())
        let update = NSMenuItem(title: busy ? "確認中…" : "状態を更新", action: #selector(refresh), keyEquivalent: "")
        update.target = self; update.isEnabled = !busy; menu.addItem(update)
        let details = NSMenuItem(title: "サーバー管理を開く", action: #selector(showDetails), keyEquivalent: "")
        details.target = self; menu.addItem(details)
    }
}
