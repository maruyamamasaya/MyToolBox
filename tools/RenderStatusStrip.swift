// Developer previews using the production view; synthetic values never enter the monitoring app.
import AppKit
@main struct RenderStatusStrip {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        if !CommandLine.arguments.contains("--live-alert-preview") {
            NSApplication.shared.setActivationPolicy(.prohibited)
        }
        let suite = "local.MyToolBox.render-status." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = MonitorStore(defaults: defaults, managesBackgroundServices: false, startsAutomatically: false)
        let engine = MonitorEngine()
        _ = await engine.sample()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        store.snapshot = await engine.sample()
        let downloadFixture = CommandLine.arguments.contains("--network-color-preview")
        let uploadFixture = CommandLine.arguments.contains("--network-color-preview-upload")
        if downloadFixture || uploadFixture, var snapshot = store.snapshot,
           let index = snapshot.readings.firstIndex(where: { $0.id == "network" }) {
            // Explicit rendering fixtures only, never fed into the real monitoring app.
            snapshot.readings[index].metrics["受信速度"] = Metric(downloadFixture ? 1_200_000 : 7400, "B/s")
            snapshot.readings[index].metrics["送信速度"] = Metric(uploadFixture ? 1_200_000 : 7400, "B/s")
            store.snapshot = snapshot
        }
        let livePreview = CommandLine.arguments.contains("--live-alert-preview")
        let alertFixture = CommandLine.arguments.contains("--alert-preview") || livePreview
        if alertFixture, var snapshot = store.snapshot {
            // Display fixtures, not measurements: BAT/SSD red, RAM/CPU temperature yellow.
            snapshot.readings = [
                Reading("battery", "BAT", ["残量": Metric(20, "%"), "電源接続": Metric(0), "充電中": Metric(0)]),
                Reading("memory", "RAM", ["使用率": Metric(80, "%"), "プレッシャー": Metric(2)]),
                Reading("storage", "SSD", ["空き容量": Metric(49e9, "B"), "総容量": Metric(1e12, "B")]),
                Reading("sensors", "Sensors", ["CPU温度": Metric(85, "°C"), "GPU温度": Metric(96, "°C")])
            ]
            store.snapshot = snapshot
        }
        let view = StatusStrip(frame: .zero)
        let savedSnapshot = store.snapshot
        let savedPreferences = store.preferences
        for compact in [false, true] {
            for order in [["network", "cpu"], ["cpu", "network"], ["network"]] {
                store.preferences.compact = compact
                store.preferences.order = order
                store.preferences.hidden = []
                var widths: [CGFloat] = []
                for rate in [0.0, 100, 9_900, 10_000, 99_000, 100_000, 9_900_000, 99_900_000] {
                    var snapshot = savedSnapshot!
                    snapshot.readings = [
                        Reading("network", "Network", ["受信速度": Metric(rate, "B/s"), "送信速度": Metric(rate / 2, "B/s")]),
                        Reading("cpu", "CPU", ["使用率": Metric(25, "%")])
                    ]
                    store.snapshot = snapshot
                    view.update(store: store)
                    widths.append(view.intrinsicContentSize.width)
                }
                precondition(Set(widths).count == 1, "Throughput changed strip width: \(widths)")
            }
        }
        store.snapshot = savedSnapshot
        store.preferences = savedPreferences
        print("PASS: throughput width stable across decimal/unit boundaries, both sizes and edge positions")
        view.appearance = NSAppearance(named: .darkAqua)
        view.update(store: store)
        view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
        let width = Int(view.bounds.width), height = Int(view.bounds.height)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * 3, pixelsHigh: height * 3, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = view.bounds.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        view.appearance?.performAsCurrentDrawingAppearance {
            NSColor(calibratedWhite: 0.25, alpha: 1).setFill(); view.bounds.fill()
            view.draw(view.bounds)
        }
        NSGraphicsContext.restoreGraphicsState()
        let filename = alertFixture ? "alert-colors-fixture.png" : downloadFixture ? "network-color-download-fixture.png" : uploadFixture ? "network-color-upload-fixture.png" : "status-strip-preview.png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "evidence/" + filename))
        if alertFixture { print("Alert values are synthetic rendering fixtures.") }
        if downloadFixture || uploadFixture { print("Network rates are synthetic rendering fixtures.") }
        print("Offscreen render (not a desktop screenshot): \(width) x \(height) pt")
        if livePreview { showLivePreview(view) }
    }
    @MainActor static func showLivePreview(_ view: StatusStrip) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 150), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "MyToolBox — 赤の点滅テスト（実測値ではありません）"
        window.isReleasedWhenClosed = false
        let content = NSView(frame: window.contentLayoutRect)
        window.contentView = content
        let label = NSTextField(wrappingLabelWithString: "赤の数値が1秒ごとに濃淡を変えます。黄色は点滅しません。\n実アプリと同じ描画・タイマーです。2分後に自動終了します。")
        label.frame = NSRect(x: 20, y: 88, width: 520, height: 42)
        content.addSubview(label)
        let background = NSView(frame: NSRect(x: 20, y: 45, width: 520, height: 30))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor(calibratedWhite: 0.25, alpha: 1).cgColor
        content.addSubview(background)
        view.frame.origin = NSPoint(x: 8, y: 4)
        background.addSubview(view)
        let note = NSTextField(labelWithString: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? "「視差効果を減らす」が有効のため、赤は固定表示です。" : "BAT・SSDの赤に注目してください。")
        note.frame = NSRect(x: 20, y: 14, width: 520, height: 22)
        content.addSubview(note)
        window.center(); window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        let closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in NSApplication.shared.terminate(nil) }
        let stop = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { _ in NSApplication.shared.terminate(nil) }
        withExtendedLifetime((window, closeObserver, stop)) { app.run() }
    }
}
