import AppKit
import SwiftUI
import WebKit

/// Official JMA page, loaded only while its menu-bar popover is open.
@MainActor final class RainRadarController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private var model: RainRadarModel?
    private var lastURL: URL?
    let weather = JMAWeatherSummaryModel()

    override init() {
        super.init()
        popover.behavior = .transient
        popover.delegate = self
    }

    var isShown: Bool { popover.isShown }

    func close() { popover.performClose(nil) }

    func toggle(anchor: NSStatusBarButton) {
        if popover.isShown { close(); return }
        let model = RainRadarModel(url: lastURL ?? weather.region.radarURL, weather: weather)
        self.model = model
        popover.contentViewController = NSHostingController(rootView: ThemeRoot {
            RainRadarView(model: model, close: { [weak self] in self?.close() })
        })
        let screen = anchor.window?.screen?.visibleFrame.size ?? NSSize(width: 800, height: 800)
        popover.contentSize = NSSize(width: min(680, screen.width - 40), height: min(790, screen.height - 70))
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        // Keep only the map position for this process; reopen at the latest time.
        lastURL = model?.mapURL ?? lastURL
        model?.webView.stopLoading()
        model?.webView.navigationDelegate = nil
        popover.contentViewController = nil
        model = nil
    }
}

@MainActor final class RainRadarModel: NSObject, ObservableObject, WKNavigationDelegate {
    static let home = URL(string: "https://www.jma.go.jp/bosai/nowc/")!
    let weather: JMAWeatherSummaryModel
    let webView: WKWebView
    @Published var busy = true
    @Published var errorMessage: String?

    init(url: URL, weather: JMAWeatherSummaryModel) {
        self.weather = weather
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.load(URLRequest(url: url, timeoutInterval: 30))
        weather.refresh()
    }

    var mapURL: URL {
        guard let fragment = webView.url?.fragment else { return Self.home }
        let position = fragment.components(separatedBy: "/").filter {
            $0.hasPrefix("lat:") || $0.hasPrefix("lon:") || $0.hasPrefix("zoom:")
        }.joined(separator: "/")
        var url = URLComponents(url: Self.home, resolvingAgainstBaseURL: false)!
        url.fragment = position.isEmpty ? nil : position
        return url.url ?? Self.home
    }

    func reload() {
        busy = true; errorMessage = nil
        webView.reloadFromOrigin()
        weather.refresh()
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        busy = true; errorMessage = nil
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { busy = false }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        busy = false; errorMessage = "地図の表示が停止しました。「更新」で読み込み直せます。"
    }
    private func fail(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        busy = false; errorMessage = "読み込めませんでした: " + error.localizedDescription
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if navigationAction.targetFrame?.isMainFrame == false { decisionHandler(.allow); return }
        if url.scheme == "https", url.host == Self.home.host, url.path == Self.home.path {
            decisionHandler(.allow)
        } else {
            // Only deliberate link clicks may open another page outside the radar.
            if navigationAction.navigationType == .linkActivated, ["https", "http"].contains(url.scheme ?? "") {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }
    }
}

private struct RainRadarWebView: NSViewRepresentable {
    let model: RainRadarModel
    func makeNSView(context: Context) -> WKWebView { model.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

private struct RainRadarView: View {
    @ObservedObject var model: RainRadarModel
    let close: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("雨雲レーダー", systemImage: "cloud.rain").font(.headline)
                if model.busy { ProgressView().controlSize(.small) }
                Spacer()
                Button("更新") { model.reload() }
                Button("ブラウザで開く") { NSWorkspace.shared.open(model.mapURL) }
                Button(action: close) { Image(systemName: "xmark") }.help("閉じる")
                    .accessibilityLabel("雨雲レーダーを閉じる")
            }.padding(12)
            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).padding(8)
            }
            JMAWeatherSummaryView(model: model.weather) { region in
                model.webView.load(URLRequest(url: region.radarURL, timeoutInterval: 30))
            }
            RainRadarWebView(model: model)
            Text("気象庁「雨雲の動き」 · 地図の＋／−で拡大縮小、▶で再生")
                .font(.caption).foregroundStyle(.secondary).padding(8)
        }
    }
}


@MainActor final class JMAWeatherSummaryModel: ObservableObject {
    static let regionKey = "weather.region.v1"
    @Published private(set) var region: JMAWeatherRegion
    @Published private(set) var observation: JMAObservation?
    @Published private(set) var forecast: JMAForecast?
    @Published private(set) var observationError: String?
    @Published private(set) var forecastError: String?
    @Published private(set) var busy = false
    private let defaults: UserDefaults
    private var task: Task<Void, Never>?
    private var automaticTask: Task<Void, Never>?
    private let observationLoader: @Sendable (JMAWeatherRegion) async throws -> JMAObservation
    private let forecastLoader: @Sendable (JMAWeatherRegion) async throws -> JMAForecast

    init(defaults: UserDefaults = .standard,
         observationLoader: @escaping @Sendable (JMAWeatherRegion) async throws -> JMAObservation = { try await JMAWeatherService.observation($0) },
         forecastLoader: @escaping @Sendable (JMAWeatherRegion) async throws -> JMAForecast = { try await JMAWeatherService.forecast($0) }) {
        self.defaults = defaults
        self.observationLoader = observationLoader; self.forecastLoader = forecastLoader
        region = JMAWeatherRegion.resolve(defaults.string(forKey: Self.regionKey) ?? "shinagawa")
    }
    func select(_ id: String) {
        region = JMAWeatherRegion.resolve(id)
        defaults.set(region.id, forKey: Self.regionKey)
        refresh()
    }
    func cancel() { task?.cancel(); task = nil; busy = false }
    func startAutomaticUpdates(interval: Duration = .seconds(600)) {
        guard automaticTask == nil else { return }
        automaticTask = Task { [weak self] in
            while !Task.isCancelled {
                if self?.busy == false { self?.refresh() }
                do { try await Task.sleep(for: interval) } catch { break }
            }
        }
    }
    func stopAutomaticUpdates() { automaticTask?.cancel(); automaticTask = nil; cancel() }
    var menuTitle: String { JMAWeatherMenu.title(observation: observation, busy: busy) }
    @discardableResult func updateMenuButton(_ button: NSButton) -> CGFloat {
        let strip = (button.subviews.first { $0 is WeatherMenuStrip } as? WeatherMenuStrip) ?? WeatherMenuStrip(frame: .zero)
        if strip.superview == nil { button.addSubview(strip) }
        strip.update(title: menuTitle, icon: forecast?.menuIcon() ?? .unknown)
        button.title = ""; button.image = nil
        strip.frame = NSRect(origin: .zero, size: strip.intrinsicContentSize)
        button.toolTip = menuToolTip
        button.setAccessibilityLabel("気象庁 今日の予報 " + (forecast?.text ?? "未取得") + " 上段 気温・下段 湿度 " + menuTitle)
        return strip.intrinsicContentSize.width
    }
    var menuToolTip: String {
        let forecastDescription = forecast?.text ?? forecastError ?? "予報取得中／未取得"
        let heading = "\(region.name) ／ 観測地点：\(region.stationName)（気象庁）"
            + "\nアイコン：今日の予報の主な天気（現在の実測ではありません）\n" + forecastDescription
        if let error = observationError { return heading + "\n取得失敗：" + error + "\nクリックで雨雲レーダー" }
        if let observation {
            return heading + "\n観測 \(Self.time(observation.date)) JST" + (observation.isStale ? "（30分以上前のため数値は非表示）" : "") + "\nクリックで雨雲レーダー"
        }
        return heading + (busy ? "\n取得中…" : "\n観測値なし") + "\nクリックで雨雲レーダー"
    }
    func waitForRefresh() async { await task?.value }
    func refresh() {
        cancel()
        observation = nil; forecast = nil; observationError = nil; forecastError = nil; busy = true
        let region = region
        let observationLoader = observationLoader; let forecastLoader = forecastLoader
        task = Task { [weak self] in
            async let observed = Self.getObservation(region, loader: observationLoader)
            async let predicted = Self.getForecast(region, loader: forecastLoader)
            let (observation, forecast) = await (observed, predicted)
            guard !Task.isCancelled, let self else { return }
            switch observation {
            case .success(let value): self.observation = value
            case .failure(let error): self.observationError = error.localizedDescription
            }
            switch forecast {
            case .success(let value): self.forecast = value
            case .failure(let error): self.forecastError = error.localizedDescription
            }
            self.busy = false
        }
    }
    private static func getObservation(_ region: JMAWeatherRegion, loader: @Sendable (JMAWeatherRegion) async throws -> JMAObservation) async -> Result<JMAObservation, Error> {
        do { return .success(try await loader(region)) } catch { return .failure(error) }
    }
    private static func getForecast(_ region: JMAWeatherRegion, loader: @Sendable (JMAWeatherRegion) async throws -> JMAForecast) async -> Result<JMAForecast, Error> {
        do { return .success(try await loader(region)) } catch { return .failure(error) }
    }
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo"); formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}

struct JMAWeatherSummaryView: View {
    @ObservedObject var model: JMAWeatherSummaryModel
    let selectRegion: (JMAWeatherRegion) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Picker("地域", selection: Binding(get: { model.region.id }, set: { id in
                    model.select(id); selectRegion(model.region)
                })) {
                    ForEach(JMAWeatherRegion.regions) { Text($0.name).tag($0.id) }
                }.frame(width: 230)
                Spacer()
                if model.busy { ProgressView().controlSize(.small); Text("気象データ取得中…").font(.caption) }
                else {
                    Text("気温 " + (model.observation?.temperature.map { String(format: "%.1f°C", $0) } ?? "—"))
                    Text("湿度 " + (model.observation?.humidity.map { String(format: "%.0f%%", $0) } ?? "—"))
                }
            }
            if let forecast = model.forecast {
                Text("今日の予報（\(forecast.areaName)）：\(forecast.text)").font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                Text("予報発表 \(JMAWeatherSummaryModel.time(forecast.reportDate)) JST").font(.caption2).foregroundStyle(.secondary)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let periods = forecast.upcomingPrecipitation(now: context.date)
                    if periods.isEmpty {
                        Text("降水確率：対象時間帯のデータなし").font(.caption).foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("降水確率（\(forecast.areaName)・6時間ごと／JST）").font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(periods) { period in
                                    VStack(spacing: 3) {
                                        Text(period.label).font(.caption2)
                                        Text(period.percent.map { "\($0)%" } ?? "—").font(.system(size: 14, weight: .semibold))
                                    }.frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            } else if let error = model.forecastError {
                Text("予報：" + error).font(.caption).foregroundStyle(.secondary)
            }
            if let observation = model.observation {
                Text("気温・湿度は地域内の実測ではなく観測所の値です。観測地点：\(model.region.stationName) ／ \(JMAWeatherSummaryModel.time(observation.date)) JST" + (observation.isStale ? "（30分以上前の観測）" : ""))
                    .font(.caption2).foregroundStyle(.secondary)
                if observation.temperature == nil || observation.humidity == nil {
                    Text("— は未観測・欠測・品質未確認。")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else if let error = model.observationError {
                Text("観測値：" + error).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.horizontal, 12).padding(.vertical, 8)
    }
}


/// Uses the same 9pt semibold digits and 10pt row spacing as StatusStrip.
@MainActor final class WeatherMenuStrip: NSView {
    private var rows = ["…°C", "…%"]
    private(set) var icon = JMAWeatherIcon.unknown
    private let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(false) // The parent status button owns the label and action.
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    func update(title: String, icon: JMAWeatherIcon = .unknown) {
        self.icon = icon
        rows = title.components(separatedBy: " ")
        invalidateIntrinsicContentSize(); needsDisplay = true
    }
    override var intrinsicContentSize: NSSize {
        let width = rows.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 34
        return NSSize(width: 22 + ceil(max(34, width + 12)), height: NSStatusBar.system.thickness)
    }
    static func symbolRect(size: NSSize, in bounds: NSRect) -> NSRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fitted = NSSize(width: size.width * scale, height: size.height * scale)
        return NSRect(x: bounds.midX - fitted.width / 2, y: bounds.midY - fitted.height / 2,
                      width: fitted.width, height: fitted.height)
    }
    static func iconColor(for icon: JMAWeatherIcon, appearance: NSAppearance) -> NSColor {
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let rgb: UInt32
        switch icon {
        case .sunny: rgb = dark ? 0xffac42 : 0xbf6100
        case .cloudy: rgb = dark ? 0xc4ccd6 : 0x657080
        case .rainy: rgb = dark ? 0x64b5ff : 0x246bc1
        case .snowy: rgb = dark ? 0x7edbf2 : 0x147c9c
        case .unknown: return .labelColor
        }
        return NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                       green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        let iconColor = Self.iconColor(for: icon, appearance: effectiveAppearance)
        let image = NSImage(systemSymbolName: icon.symbol, accessibilityDescription: nil)
        let tinted = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            if let image { image.draw(in: Self.symbolRect(size: image.size, in: rect)) }
            iconColor.setFill()
            rect.fill(using: .sourceIn)
            return true
        }
        tinted.draw(in: NSRect(x: 3, y: (bounds.height - 16) / 2, width: 16, height: 16))
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
        let bottomY = (bounds.height - 20) / 2
        for (row, text) in rows.prefix(2).enumerated() {
            let width = (text as NSString).size(withAttributes: attributes).width
            (text as NSString).draw(at: NSPoint(x: 22 + (bounds.width - 22 - width) / 2,
                                               y: bottomY + (row == 0 ? 10 : 0)), withAttributes: attributes)
        }
    }
}
