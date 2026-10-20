import AppKit
import SwiftUI

@main struct VerifyWeather {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let suite = "local.MyToolBox.WeatherProbe." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = JMAWeatherSummaryModel(defaults: defaults)
        guard model.region.id == "shinagawa" else { fatalError("default region") }
        model.refresh(); await model.waitForRefresh()
        guard let observation = model.observation, let forecast = model.forecast,
              observation.temperature != nil, observation.humidity != nil else {
            fatalError("Live data failed: \(model.observationError ?? "") \(model.forecastError ?? "")")
        }
        guard !forecast.upcomingPrecipitation().isEmpty else { fatalError("live precipitation missing") }
        print("PRECIPITATION: " + forecast.upcomingPrecipitation().map { $0.label + " " + ($0.percent.map { "\($0)%" } ?? "—") }.joined(separator: ", "))
        print("LIVE: \(model.region.name), station \(model.region.stationName), \(observation.temperature!)°C, \(observation.humidity!)%, observed \(observation.date), forecast \(forecast.text), published \(forecast.reportDate)")
        try FileManager.default.createDirectory(atPath: "evidence/weather", withIntermediateDirectories: true)
        for theme in VisualTheme.allCases {
            let host = NSHostingView(rootView: ThemeRoot(override: theme) {
                JMAWeatherSummaryView(model: model, selectRegion: { _ in })
            })
            let size = NSSize(width: 680, height: 220)
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
            window.displayIfNeeded()
            try await Task.sleep(for: .milliseconds(150))
            host.layoutSubtreeIfNeeded()
            let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "evidence/weather/\(theme.rawValue).png"))
            print("RENDER: " + theme.rawValue)
        }
        model.select("yokohama"); await model.waitForRefresh()
        guard model.observation != nil, model.forecast != nil,
              JMAWeatherSummaryModel(defaults: defaults).region.id == "yokohama" else { fatalError("region change/persistence") }
        model.select("osaka"); model.select("shinagawa"); await model.waitForRefresh()
        guard model.region.id == "shinagawa", model.forecast?.areaName == "東京地方" else { fatalError("stale result") }
        model.cancel()
        let counter = WeatherProbeCounter()
        let automatic = JMAWeatherSummaryModel(defaults: defaults, observationLoader: { _ in
            await counter.increment(); return observation
        }, forecastLoader: { _ in forecast })
        automatic.startAutomaticUpdates(interval: .milliseconds(50))
        automatic.startAutomaticUpdates(interval: .milliseconds(50)) // must not create another loop
        try await Task.sleep(for: .milliseconds(180))
        await automatic.waitForRefresh()
        let count = await counter.value
        guard (2...5).contains(count), automatic.menuTitle.contains("°C"), automatic.observation != nil else { fatalError("background updates") }
        automatic.stopAutomaticUpdates()
        try await Task.sleep(for: .milliseconds(100))
        guard await counter.value == count else { fatalError("automatic stop") }
        let failed = JMAWeatherSummaryModel(defaults: defaults, observationLoader: { _ in
            throw URLError(.notConnectedToInternet)
        }, forecastLoader: { _ in forecast })
        failed.refresh(); await failed.waitForRefresh()
        guard failed.menuTitle == "—°C —%", failed.observationError != nil, failed.forecast != nil else { fatalError("offline menu") }
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        button.isBordered = false
        let width = automatic.updateMenuButton(button)
        button.setFrameSize(NSSize(width: width, height: NSStatusBar.system.thickness))
        guard button.subviews.count == 1, button.subviews.first is WeatherMenuStrip else { fatalError("two-row strip") }
        _ = automatic.updateMenuButton(button)
        guard button.subviews.count == 1 else { fatalError("duplicate strip") }
        let bitmap = button.bitmapImageRepForCachingDisplay(in: button.bounds)!
        button.cacheDisplay(in: button.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "evidence/weather/menu-button-two-rows.png"))
        guard (button.subviews.first as? WeatherMenuStrip)?.icon == forecast.menuIcon() else { fatalError("forecast icon wiring") }
        let absentForecast = JMAWeatherSummaryModel(defaults: defaults, observationLoader: { _ in observation }, forecastLoader: { _ in
            throw URLError(.notConnectedToInternet)
        })
        absentForecast.refresh(); await absentForecast.waitForRefresh()
        guard absentForecast.observation != nil, absentForecast.forecastError != nil else { fatalError("forecast failure independence") }
        let failureButton = NSButton(frame: button.frame)
        absentForecast.updateMenuButton(failureButton)
        guard (failureButton.subviews.first as? WeatherMenuStrip)?.icon == .unknown else { fatalError("missing forecast icon") }
        let variants = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: NSStatusBar.system.thickness))
        for (index, icon) in JMAWeatherIcon.allCases.enumerated() {
            guard let symbol = NSImage(systemSymbolName: icon.symbol, accessibilityDescription: nil) else { fatalError("missing symbol") }
            let fitted = WeatherMenuStrip.symbolRect(size: symbol.size, in: NSRect(x: 0, y: 0, width: 16, height: 16))
            guard abs(fitted.width / fitted.height - symbol.size.width / symbol.size.height) < 0.0001,
                  fitted.width <= 16.0001, fitted.height <= 16.0001 else { fatalError("distorted symbol") }
            print("ASPECT: \(icon.rawValue), original \(symbol.size), fitted \(fitted.size)")
            let strip = WeatherMenuStrip(frame: NSRect(x: index * 76, y: 0, width: 70, height: Int(NSStatusBar.system.thickness)))
            strip.update(title: model.menuTitle, icon: icon)
            variants.addSubview(strip)
        }
        for (name, appearanceName) in [("dark", NSAppearance.Name.darkAqua), ("light", NSAppearance.Name.aqua)] {
            let appearance = NSAppearance(named: appearanceName)!
            variants.appearance = appearance
            variants.wantsLayer = true
            variants.layer?.backgroundColor = (name == "dark" ? NSColor(srgbRed: 0.10, green: 0.10, blue: 0.12, alpha: 1) : NSColor.white).cgColor
            for view in variants.subviews { view.needsDisplay = true }
            variants.displayIfNeeded()
            let iconsBitmap = variants.bitmapImageRepForCachingDisplay(in: variants.bounds)!
            variants.cacheDisplay(in: variants.bounds, to: iconsBitmap)
            try iconsBitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "evidence/weather/menu-icons-color-\(name).png"))
            let sunny = WeatherMenuStrip.iconColor(for: .sunny, appearance: appearance).usingColorSpace(.sRGB)!
            let rainy = WeatherMenuStrip.iconColor(for: .rainy, appearance: appearance).usingColorSpace(.sRGB)!
            guard sunny.redComponent > sunny.greenComponent, sunny.greenComponent > sunny.blueComponent,
                  rainy.blueComponent > rainy.redComponent else { fatalError("weather color mapping") }
        }
        print("PASS: live forecast icon wiring, missing forecast fallback, five native symbol variants (synthetic weather states)")
        print("PASS: automatic update without webview, idempotent start, stop, offline partial success, native menu-button rendering")
        print("PASS: real summary model, two regions, isolated persistence, rapid selection/cancellation, four offscreen themes")
    }
}

actor WeatherProbeCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}
