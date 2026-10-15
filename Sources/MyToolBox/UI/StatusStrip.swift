import AppKit

/// Mixed single-/two-row menu-bar display matching the user's reference; contains no monitoring work.
@MainActor final class StatusStrip: NSView {
    struct Cell {
        var top: String; var bottom: String; var width: CGFloat
        var topSeverity = MenuSeverity.normal; var bottomSeverity = MenuSeverity.normal
        var singleLine = false
        var memoryIcon = false
    }
    private var cells: [Cell] = []
    private var compact = false
    private var alerts = MenuAlerts()
    private var pulseTimer: Timer?
    private var dimmed = false
    deinit { pulseTimer?.invalidate() }
    private func updatePulse() {
        let critical = cells.contains { $0.topSeverity == .critical || $0.bottomSeverity == .critical }
        guard critical, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            pulseTimer?.invalidate(); pulseTimer = nil; dimmed = false; return
        }
        guard pulseTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    self.dimmed = false
                } else { self.dimmed.toggle() }
                self.needsDisplay = true
            }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common); pulseTimer = timer
    }
    var onPress: (() -> Void)?
    override var intrinsicContentSize: NSSize { NSSize(width: max(24, cells.reduce(0) { $0 + $1.width }), height: NSStatusBar.system.thickness) }
    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true); setAccessibilityRole(.button)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
    func update(store: MonitorStore) {
        compact = store.preferences.compact
        if store.snapshot == nil { alerts.reset() }
        let levels = store.snapshot.map { alerts.levels($0) } ?? [:]
        let labels = ["cpu": "CPU", "gpu": "GPU", "memory": "RAM", "storage": "SSD", "battery": "BAT", "sensors": "TEMP"]
        func text(_ id: String, _ key: String) -> String {
            guard let snapshot = store.snapshot else { return "…" }
            guard let metric = snapshot.metric(id, key) else { return "—" }
            if id == "network" { return MetricFormat.networkMenu(metric) }
            guard metric.value != nil else { return metric.state == .waiting ? "…" : "—" }
            if id == "storage", let bytes = metric.value { return String(format: "%.0fGB", floor(bytes / 1_000_000_000)) }
            if metric.unit == "%", let value = metric.value { return String(format: "%.0f%%", value) }
            return MetricFormat.string(metric, preferences: store.preferences).replacingOccurrences(of: " ", with: "")
        }
        func makeCell(_ top: String, _ bottom: String) -> Cell {
            let font = NSFont.monospacedDigitSystemFont(ofSize: compact ? 8 : 9, weight: .semibold)
            let width = max((top as NSString).size(withAttributes: [.font: font]).width, (bottom as NSString).size(withAttributes: [.font: font]).width)
            return Cell(top: top, bottom: bottom, width: ceil(max(compact ? 28 : 34, width + (compact ? 8 : 12))))
        }
        func singleCell(_ label: String, _ value: String, memoryIcon: Bool = false) -> Cell {
            let font = NSFont.monospacedDigitSystemFont(ofSize: compact ? 11 : 12, weight: .medium)
            let width = (value as NSString).size(withAttributes: [.font: font]).width
            var cell = Cell(top: label, bottom: value, width: ceil(width + (memoryIcon ? 23 : 0) + (compact ? 8 : 12)))
            cell.singleLine = true
            cell.memoryIcon = memoryIcon
            return cell
        }
        func sensorNumber(_ key: String) -> String {
            guard let snapshot = store.snapshot else { return "…" }
            guard let metric = snapshot.metric("sensors", key), let value = metric.value else { return "—" }
            let converted = metric.unit == "°C" && store.preferences.fahrenheit ? value * 9 / 5 + 32 : value
            if metric.unit == "°C" { return String(format: "%.1f%@", converted, store.preferences.fahrenheit ? "°F" : "°C") }
            return String(format: "%.0f", converted)
        }
        var fanCells: [Cell] = []
        var memoryCells: [Cell] = []
        var temperatureCells: [Cell] = []
        cells = store.preferences.order.filter { !store.preferences.hidden.contains($0) }.flatMap { id -> [Cell] in
            if id == "sensors" {
                let count = store.snapshot?.metric("sensors", "ファン数")?.value.flatMap { SensorsMonitor.fanCount($0) }
                let fans = count.map { count in count > 0 ? (1...count).map { sensorNumber("ファン\($0)回転数") }.joined(separator: "/") : "—" } ?? (store.snapshot == nil ? "…" : "—")
                var cpu = singleCell("CPU温度", "CPU " + sensorNumber("CPU温度"))
                var gpu = singleCell("GPU温度", "GPU " + sensorNumber("GPU温度"))
                cpu.bottomSeverity = levels["CPU温度"] ?? .normal
                gpu.bottomSeverity = levels["GPU温度"] ?? .normal
                fanCells = [makeCell("FAN", fans)]
                temperatureCells = [cpu, gpu]
                return []
            }
            if id == "network" {
                let received = text(id, "受信速度"); let sent = text(id, "送信速度")
                var cell = makeCell("↓" + received, "↑" + sent)
                cell.topSeverity = received.hasSuffix("MB/s") ? .warning : .normal
                cell.bottomSeverity = sent.hasSuffix("MB/s") ? .warning : .normal
                return [cell]
            }
            let top = (labels[id] ?? id) + (id == "battery" && store.snapshot?.metric("battery", "充電中")?.value == 1 ? " ⚡︎" : "")
            let key = ["storage": "空き容量", "battery": "残量"][id] ?? "使用率"
            var cell = makeCell(top, text(id, key))
            cell.bottomSeverity = levels[id] ?? .normal
            if id == "memory" {
                let available = store.snapshot?.metric("memory", "利用可能容量（推定）")
                let capacity = available?.value.map { String(format: "%.2f GB", $0 / 1_000_000_000) } ?? (store.snapshot == nil ? "…" : "—")
                var remaining = singleCell("RAM残り", capacity, memoryIcon: true)
                remaining.bottomSeverity = available?.value == nil ? .normal : levels[id] ?? .normal
                memoryCells = [remaining]
                return [cell]
            }
            return [cell]
        }
        cells += fanCells + memoryCells + temperatureCells
        updatePulse()
        setAccessibilityLabel("MyToolBox " + cells.map { $0.top + " " + $0.bottom + ($0.bottomSeverity == .critical ? " 要確認" : $0.bottomSeverity == .warning ? " 注意" : "") }.joined(separator: ", ") + "。クリックで詳細と設定")
        toolTip = "MyToolBox — 上段↓受信／下段↑送信。MB/s表示の通信速度は黄色。監視値は注意時に黄色、要確認時に赤でゆっくり明滅（動きを減らす設定時は赤固定）。BATは電池駆動時50%以下で黄色、20%以下で赤。RAMは使用率、RAM残りは総容量−推定使用容量（10進GB、即時未使用freeとは異なる）、SSDは空き容量（10進GB・小数点以下切捨て）、⚡︎は充電中。CPU/GPU温度はセンサー平均、FANは番号順の実回転数（rpm）。— は取得不可、… は計測待ち。クリックで詳細と設定"
        invalidateIntrinsicContentSize(); needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !cells.isEmpty else {
            NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "MyToolBox")?.draw(in: NSRect(x: 3, y: (bounds.height - 16) / 2, width: 18, height: 16))
            return
        }
        let font = NSFont.monospacedDigitSystemFont(ofSize: compact ? 8 : 9, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
        let lineHeight: CGFloat = compact ? 9 : 10
        let bottomY = (bounds.height - lineHeight * 2) / 2
        var x: CGFloat = 0
        for cell in cells {
            if cell.singleLine {
                let singleFont = NSFont.monospacedDigitSystemFont(ofSize: compact ? 11 : 12, weight: .medium)
                let color: NSColor = cell.bottomSeverity == .critical
                    ? NSColor(calibratedRed: 1, green: 0.35, blue: 0.35, alpha: dimmed ? 0.6 : 1)
                    : cell.bottomSeverity == .warning ? NSColor(calibratedRed: 1, green: 0.89, blue: 0.4, alpha: 1) : .labelColor
                let attrs: [NSAttributedString.Key: Any] = [.font: singleFont, .foregroundColor: color]
                let size = (cell.bottom as NSString).size(withAttributes: attrs)
                let iconSpace: CGFloat = cell.memoryIcon ? 23 : 0
                let start = x + (cell.width - size.width - iconSpace) / 2
                if cell.memoryIcon {
                    drawMemoryIcon(at: NSPoint(x: start, y: (bounds.height - 12) / 2), color: color)
                }
                (cell.bottom as NSString).draw(at: NSPoint(x: start + iconSpace, y: (bounds.height - size.height) / 2), withAttributes: attrs)
                x += cell.width
                continue
            }
            for (text, y, severity) in [(cell.top, bottomY + lineHeight, cell.topSeverity), (cell.bottom, bottomY, cell.bottomSeverity)] {
                var textAttributes = attributes
                if severity == .warning { textAttributes[.foregroundColor] = NSColor(calibratedRed: 1, green: 0.89, blue: 0.4, alpha: 1) }
                if severity == .critical { textAttributes[.foregroundColor] = NSColor(calibratedRed: 1, green: 0.35, blue: 0.35, alpha: dimmed ? 0.6 : 1) }
                let size = (text as NSString).size(withAttributes: attributes)
                (text as NSString).draw(at: NSPoint(x: x + (cell.width - size.width) / 2, y: y), withAttributes: textAttributes)
            }
            x += cell.width
        }
    }
    /// Original vector RAM module: elongated PCB, three chips, bottom connector fingers.
    private func drawMemoryIcon(at origin: NSPoint, color: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: origin.x, yBy: origin.y); transform.concat()
        color.setStroke(); color.setFill()
        let board = NSBezierPath(roundedRect: NSRect(x: 0.5, y: 2.5, width: 19, height: 9), xRadius: 1, yRadius: 1)
        board.lineWidth = 1; board.stroke()
        for x: CGFloat in [3, 8, 13] {
            let chip = NSBezierPath(rect: NSRect(x: x, y: 5, width: 3, height: 4))
            chip.lineWidth = 0.8; chip.stroke()
        }
        for x: CGFloat in [2, 4, 6, 8, 12, 14, 16, 18] {
            NSRect(x: x, y: 0, width: 1, height: 2).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    override func mouseDown(with event: NSEvent) { onPress?() }
    override func accessibilityPerformPress() -> Bool { onPress?(); return true }
}
