import AppKit
import SwiftUI
import ServiceManagement

@MainActor final class MonitorStore: ObservableObject {
    @Published var snapshot: Snapshot?
    @Published var history = History()
    @Published var preferences: Preferences { didSet { preferences.save(to: defaults); updateStatus?() } }
    @Published var selected = "overview"
    @Published var alertLevels: [String: MenuSeverity] = [:]
    private var alerts = MenuAlerts()
    @Published var loginStatus = "未確認"
    @Published var loginError: String?
    @Published var sleeping = false
    @Published var logPreferences: LogPreferences { didSet { if managesBackgroundServices { logPreferences.save(to: defaults) } } }
    @Published var logError: String?
    @Published var lastLogDate: Date?
    private let logger = MonitoringLog()
    @Published var securityReadings = SecurityItem.allCases.map { SecurityReading(item: $0) }
    @Published private(set) var securityChecking = false
    private let securityCollector = SecurityCollector()
    private let engine = MonitorEngine()
    private var loop: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    var updateStatus: (() -> Void)?

    let managesBackgroundServices: Bool
    private let defaults: UserDefaults
    init(defaults: UserDefaults = IndependentTools.defaults,
         managesBackgroundServices: Bool = true, startsAutomatically: Bool = true) {
        self.defaults = defaults
        self.managesBackgroundServices = managesBackgroundServices
        preferences = Preferences.load(from: defaults)
        logPreferences = LogPreferences.load(from: defaults)
        guard startsAutomatically else { return }
        let nc = NSWorkspace.shared.notificationCenter
        observers.append(nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.suspend() }
        })
        observers.append(nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.resume() }
        })
        refreshLoginStatus(); start(); refreshSecurity()
    }
    func refreshSecurityIfNeeded() {
        if securityReadings.allSatisfy({ $0.checkedAt == nil }) { refreshSecurity() }
    }
    func refreshSecurity() {
        guard !securityChecking else { return }
        securityChecking = true
        securityReadings = securityReadings.map { SecurityReading(item: $0.item, checkedAt: $0.checkedAt) }
        Task { [weak self, securityCollector] in
            let readings = await securityCollector.read()
            guard let self else { return }
            securityReadings = readings
            securityChecking = false
        }
    }
    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                defaults.synchronize()
                let latest = Preferences.load(from: defaults)
                if latest != preferences { preferences = latest }
                let latestLogging = LogPreferences.load(from: defaults)
                if latestLogging != logPreferences { logPreferences = latestLogging }
                let result = await engine.sample(interface: preferences.interface)
                guard !Task.isCancelled, !sleeping else { break }
                snapshot = result; history.append(result); alertLevels = alerts.levels(result); updateStatus?()
                if managesBackgroundServices {
                    do {
                        if try await logger.append(result, preferences: logPreferences) { lastLogDate = result.date }
                        logError = nil
                    } catch { logError = error.localizedDescription }
                }
                try? await Task.sleep(nanoseconds: UInt64(preferences.interval * 1_000_000_000))
            }
        }
    }
    func suspend() {
        sleeping = true; loop?.cancel(); loop = nil; history.breakSegment()
        snapshot = nil; alerts.reset(); alertLevels = [:]; updateStatus?()
    }
    func resume() {
        Task {
            await engine.reset()
            await logger.reset()
            sleeping = false; start()
        }
    }
    func stop() {
        loop?.cancel(); loop = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }
    func refreshLoginStatus() {
        guard managesBackgroundServices else { loginStatus = "本体で管理"; return }
        switch SMAppService.mainApp.status {
        case .enabled: loginStatus = "有効"
        case .notRegistered: loginStatus = "未登録"
        case .requiresApproval: loginStatus = "システム設定で承認待ち"
        case .notFound: loginStatus = "アプリが見つかりません"
        @unknown default: loginStatus = "不明"
        }
    }
    func setLogin(_ enabled: Bool) {
        guard managesBackgroundServices else { loginStatus = "本体で管理"; return }
        loginError = nil
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { loginError = error.localizedDescription }
        refreshLoginStatus()
    }
    func move(_ section: String, by delta: Int) {
        guard let i = preferences.order.firstIndex(of: section), preferences.order.indices.contains(i + delta) else { return }
        preferences.order.swapAt(i, i + delta)
    }
    func primary(_ id: String) -> Metric {
        let key = ["network": "受信速度", "battery": "残量", "sensors": "CPU温度"][id] ?? "使用率"
        return snapshot?.metric(id, key) ?? Metric(.waiting, sleeping ? "スリープ中" : "初回取得待ち")
    }
}
