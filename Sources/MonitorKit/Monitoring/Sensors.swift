import Foundation

/// M1 Max key mapping referenced from Stats (MIT); see Resources/Stats-LICENSE.txt.
/// Sensor names are community mappings, not calibrated/Apple-guaranteed physical positions.
public struct SensorsMonitor {
    static let cpuKeys = ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b"]
    static let gpuKeys = ["Tg05", "Tg0D", "Tg0L", "Tg0T"]
    public init() {}
    static func temperature(_ value: Double, source: String) -> Metric {
        guard value.isFinite, value > 0, value <= 130 else { return Metric(.unavailable, "\(source): 温度範囲外／無効値", unit: "°C") }
        return Metric(value, "°C", reason: source)
    }
    static func average(_ metrics: [Metric], expected: Int) -> Metric {
        guard metrics.count == expected, expected > 0, metrics.allSatisfy({ $0.state == .available && $0.value != nil }) else {
            return Metric(.unavailable, "温度センサーの一部または全部が取得不可。欠損を除いて平均しない", unit: "°C")
        }
        return Metric(metrics.compactMap(\.value).reduce(0,+) / Double(expected), "°C", reason: "SMC \(expected)センサー平均・5秒周期。センサー位置と絶対精度は未校正")
    }
    static func fan(_ value: Double, source: String) -> Metric {
        guard value.isFinite, (0...20000).contains(value) else { return Metric(.unavailable, "\(source): 回転数範囲外", unit: "rpm") }
        return Metric(value, "rpm", reason: source + "（実回転数、0は停止値）")
    }
    static func fanCount(_ value: Double) -> Int? {
        guard value.isFinite, (0...8).contains(value), value.rounded(.towardZero) == value else { return nil }
        return Int(value)
    }
    public func read() -> Reading {
        var metrics: [String: Metric] = [:]
        let reader: SMCReader
        do { reader = try SMCReader() }
        catch {
            for key in ["CPU温度", "GPU温度", "ファン回転数"] { metrics[key] = Metric(.unavailable, String(describing: error), unit: key == "ファン回転数" ? "rpm" : "°C") }
            return Reading("sensors", "Sensors", metrics)
        }
        if sysString("machdep.cpu.brand_string") == "Apple M1 Max" {
            for (name, keys) in [("CPU", Self.cpuKeys), ("GPU", Self.gpuKeys)] {
                var group: [Metric] = []
                for key in keys {
                    let metric: Metric
                    do {
                        let sample = try reader.read(key)
                        guard ["flt ", "sp78"].contains(sample.type) else { throw SMCFailure.message("温度の未対応型: \(sample.type)") }
                        metric = Self.temperature(sample.value, source: "\(key) [\(sample.type)]")
                    } catch { metric = Metric(.unavailable, "\(key): \(error)", unit: "°C") }
                    metrics["\(name) \(key)"] = metric; group.append(metric)
                }
                metrics[name + "温度"] = Self.average(group, expected: keys.count)
                if name == "CPU" {
                    metrics["CPU Eコア温度"] = Self.average(Array(group.prefix(2)), expected: 2)
                    metrics["CPU Pコア温度"] = Self.average(Array(group.dropFirst(2)), expected: 8)
                }
            }
        } else {
            for name in ["CPU温度", "GPU温度"] { metrics[name] = Metric(.unavailable, "温度キー対応はM1 Maxのみ確認済み", unit: "°C") }
        }
        do {
            let sample = try reader.read("FNum")
            guard sample.type == "ui8 ", let count = Self.fanCount(sample.value) else { throw SMCFailure.message("FNumの型／個数不正") }
            metrics["ファン数"] = Metric(Double(count), "", reason: "FNum")
            var fans: [Metric] = []
            for index in 0..<count {
                let key = "F\(index)Ac"; let metric: Metric
                do {
                    let sample = try reader.read(key)
                    guard ["flt ", "fpe2"].contains(sample.type) else { throw SMCFailure.message("回転数の未対応型: \(sample.type)") }
                    metric = Self.fan(sample.value, source: "\(key) [\(sample.type)]")
                } catch { metric = Metric(.unavailable, "\(key): \(error)", unit: "rpm") }
                metrics["ファン\(index + 1)回転数"] = metric; fans.append(metric)
            }
            if count == 0 { metrics["ファン回転数"] = Metric(.notPresent, "FNum=0", unit: "rpm") }
            else if fans.allSatisfy({ $0.value != nil }) { metrics["ファン回転数"] = Metric(fans.compactMap(\.value).max()!, "rpm", reason: "全\(count)基の最大値。メニューには各基を番号順に表示") }
            else { metrics["ファン回転数"] = Metric(.unavailable, "ファンの一部が取得不可", unit: "rpm") }
        } catch { metrics["ファン回転数"] = Metric(.unavailable, "FNum: \(error)", unit: "rpm") }
        return Reading("sensors", "Sensors", metrics, notes: ["取得: \(ISO8601DateFormatter().string(from: Date()))。5秒周期・読み取り専用。", "AppleSMCの非公開ABI。CPU10点/GPU4点の平均。OS・機種依存、絶対温度の校正とParallels比較は未実施。", "ファンはF*Acの実回転数。制御・目標回転数への書き込みなし。キー対応参照: Stats (MIT)、同梱Stats-LICENSE.txt。"])
    }
}
