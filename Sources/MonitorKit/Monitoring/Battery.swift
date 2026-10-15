import Foundation
import IOKit
import IOKit.ps
public struct BatteryMonitor {
    public init() {}
    public func read() -> Reading {
        var m: [String: Metric] = [:]; var notes: [String] = []
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return Reading("battery", "Battery", ["残量": Metric(.unavailable, "IOPowerSources読取失敗")])
        }
        var battery: [String: Any]?
        for source in sources {
            if let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any], d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType { battery = d; break }
        }
        guard let battery else { return Reading("battery", "Battery", ["残量": Metric(.notPresent, "内蔵バッテリーなし")]) }
        if let current = battery[kIOPSCurrentCapacityKey] as? NSNumber, let max = battery[kIOPSMaxCapacityKey] as? NSNumber, max.doubleValue > 0 { m["残量"] = Metric(current.doubleValue / max.doubleValue * 100, "%") }
        else { m["残量"] = Metric(.unavailable, "容量キー不足") }
        for (title,key) in [("充電中",kIOPSIsChargingKey), ("電源接続",kIOPSPowerSourceStateKey)] {
            if title == "電源接続", let state = battery[key] as? String { m[title] = Metric(state == kIOPSACPowerValue ? 1 : 0, "", reason: state) }
            else if let value = battery[key] as? NSNumber { m[title] = Metric(value.doubleValue, "", reason: value.boolValue ? "はい" : "いいえ") }
            else { m[title] = Metric(.unavailable, "電源状態キー不足") }
        }
        let remaining = IOPSGetTimeRemainingEstimate()
        m["推定残り時間"] = remaining >= 0 ? Metric(remaining / 60, "min", reason: "OS推定") : Metric(.unavailable, remaining == -2 ? "外部電源使用中" : "OS推定なし")
        notes.append("健康状態: \(battery[kIOPSBatteryHealthKey] as? String ?? "取得不可")")
        let devices = entries("AppleSmartBattery"); defer { devices.forEach { IOObjectRelease($0) } }
        if let device = devices.first {
            // Whitelist individual properties: never collect serials or complete registry dictionaries.
            var d: [String: Any] = [:]
            for key in ["CycleCount", "AppleRawMaxCapacity", "DesignCapacity", "Temperature", "Voltage", "Amperage"] { d[key] = property(device, key) }
            m["サイクル数"] = number(d, "CycleCount")
            m["最大容量（推定）"] = number(d, "AppleRawMaxCapacity", unit: "mAh")
            m["設計容量"] = number(d, "DesignCapacity", unit: "mAh")
            if let max = m["最大容量（推定）"]?.value, let design = m["設計容量"]?.value, design > 0 { m["容量維持率（推定）"] = Metric(max / design * 100, "%") }
            // Unit convention is undocumented; report as unverified, not a measured temperature.
            m["温度"] = Metric(.unavailable, "Temperature rawキーありの場合も単位・校正未検証", unit: "°C")
            m["電力"] = Metric(.unavailable, "Amperageの符号・単位・電源経路未検証", unit: "W")
        } else {
            for key in ["サイクル数", "最大容量（推定）", "設計容量", "温度", "電力"] { m[key] = Metric(.unavailable, "AppleSmartBatteryキー未取得") }
        }
        notes.append("サイクル・容量は機種依存のAppleSmartBattery。AppleRawMaxCapacity/DesignCapacityをmAhと解釈（推定、校正未検証）。MaxCapacity=100をmAhとして使用しない。")
        return Reading("battery", "Battery", m, notes: notes)
    }
}
