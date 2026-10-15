import Foundation

public enum MenuSeverity: Int, Sendable { case normal, warning, critical }

/// Presentation thresholds, not hardware safety limits. Evaluated from raw units.
public struct MenuAlerts {
    private struct LoadState {
        var level = MenuSeverity.normal
        var yellowSince: Double?
        var redSince: Double?
        var recoverySince: Double?
        var last: Double?
    }
    private var loads: [String: LoadState] = [:]
    public init() {}
    public mutating func reset() { loads = [:] }
    public mutating func levels(_ snapshot: Snapshot) -> [String: MenuSeverity] {
        func value(_ section: String, _ key: String) -> Double? {
            guard let metric = snapshot.metric(section, key), metric.state == .available,
                  let v = metric.value, v.isFinite else { return nil }
            return v
        }
        var result: [String: MenuSeverity] = [:]
        for id in ["cpu", "gpu"] {
            result[id] = load(id, value: value(id, "使用率"), time: snapshot.uptime)
        }
        switch value("memory", "プレッシャー") {
        case 2: result["memory"] = .warning
        case 4: result["memory"] = .critical
        default: result["memory"] = .normal
        }
        if let free = value("storage", "空き容量"), let total = value("storage", "総容量"), total > 0, free >= 0, free <= total {
            result["storage"] = free / total < 0.05 || free < 20e9 ? .critical : free / total < 0.10 || free < 50e9 ? .warning : .normal
        }
        if value("battery", "電源接続") == 0, value("battery", "充電中") == 0,
           let percent = value("battery", "残量"), (0...100).contains(percent) {
            result["battery"] = percent <= 20 ? .critical : percent <= 50 ? .warning : .normal
        }
        for key in ["CPU温度", "GPU温度"] {
            if let celsius = value("sensors", key) {
                result[key] = celsius >= 95 ? .critical : celsius >= 80 ? .warning : .normal
            }
        }
        return result
    }
    private mutating func load(_ id: String, value: Double?, time: Double) -> MenuSeverity {
        guard let value, (0...100).contains(value), time.isFinite else { loads[id] = nil; return .normal }
        var state = loads[id] ?? LoadState()
        if let last = state.last {
            if time == last { return state.level } // Settings redraw is not a new observation.
            if time < last || time - last > 10 { state = LoadState() }
        }
        state.last = time
        state.yellowSince = value >= 80 ? state.yellowSince ?? time : nil
        state.redSince = value >= 95 ? state.redSince ?? time : nil
        if let since = state.redSince, time - since >= 10 { state.level = .critical }
        else if state.level == .normal, let since = state.yellowSince, time - since >= 5 { state.level = .warning }
        let recovering = state.level == .critical ? value < 90 : state.level == .warning && value < 75
        state.recoverySince = recovering ? state.recoverySince ?? time : nil
        if let since = state.recoverySince, time - since >= 5 {
            state.level = value < 75 ? .normal : .warning
            state.recoverySince = nil
        }
        loads[id] = state
        return state.level
    }
}
