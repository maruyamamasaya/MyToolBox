import Foundation
public struct Preferences: Codable, Equatable, Sendable {
    public static let sections = ["cpu", "gpu", "memory", "network", "storage", "battery", "sensors"]
    public var order = ["network", "cpu", "memory", "storage", "battery", "gpu", "sensors"]
    public var hidden: Set<String> = ["gpu"]
    public var sensorMenuVersion: Int? = 1
    public var interval: Double = 1
    public var compact = false
    public var binaryUnits = true
    public var fahrenheit = false
    public var interface = "auto"
    public init() {}
    public func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "monitor.preferences.v1") }
    }
    public static func load(from defaults: UserDefaults = .standard) -> Preferences {
        guard let data = defaults.data(forKey: "monitor.preferences.v1"), var p = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        if p.sensorMenuVersion == nil { p.hidden.remove("sensors"); p.sensorMenuVersion = 1 }
        p.interval = [1.0,2,5].contains(p.interval) ? p.interval : 1
        var seen = Set<String>()
        p.order = (p.order + sections).filter { sections.contains($0) && seen.insert($0).inserted }
        p.hidden.formIntersection(sections)
        return p
    }
}
public enum MetricFormat {
    /// Menu-only decimal throughput: minimum KB/s, no fractional digits at 10 KB/s,
    /// switch to MB/s at 100 KB/s. Promote rounded boundary values as well.
    public static func networkMenu(_ metric: Metric) -> String {
        guard let bytes = metric.value else { return metric.state == .waiting ? "…" : "—" }
        guard metric.unit == "B/s", bytes.isFinite, bytes >= 0 else { return "—" }
        let kb = bytes / 1_000
        if kb.rounded() >= 100 { return String(format: "%.1fMB/s", bytes / 1_000_000) }
        if (kb * 10).rounded() / 10 >= 10 { return String(format: "%.0fKB/s", kb) }
        return String(format: "%.1fKB/s", kb)
    }

    public static func string(_ m: Metric, preferences p: Preferences) -> String {
        guard let v = m.value else {
            switch m.state { case .waiting: return "計測待ち"; case .notPresent: return "非搭載"; default: return "取得不可" }
        }
        if m.unit == "B" || m.unit == "B/s" {
            let base = p.binaryUnits ? 1024.0 : 1000.0
            let names = p.binaryUnits ? ["B", "KiB", "MiB", "GiB", "TiB"] : ["B", "kB", "MB", "GB", "TB"]
            var value = v; var i = 0
            while abs(value) >= base && i < 4 { value /= base; i += 1 }
            return String(format: "%.1f %@%@", value, names[i], m.unit == "B/s" ? "/s" : "")
        }
        if m.unit == "°C", p.fahrenheit { return String(format: "%.1f °F", v * 9 / 5 + 32) }
        return String(format: "%.1f%@", v, m.unit)
    }
}
