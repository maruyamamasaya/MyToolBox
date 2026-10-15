import Foundation
import IOKit
import Metal
public struct GPUMonitor {
    public init() {}
    public func read() -> Reading {
        let devices = entries("IOAccelerator"); defer { devices.forEach { IOObjectRelease($0) } }
        var utilizations: [Double] = []
        for device in devices {
            if let stats = property(device, "PerformanceStatistics") as? [String: Any], let n = stats["Device Utilization %"] as? NSNumber, (0...100).contains(n.doubleValue) { utilizations.append(n.doubleValue) }
        }
        let device = MTLCreateSystemDefaultDevice()
        var m: [String: Metric] = ["使用率": utilizations.count == 1 ? Metric(utilizations[0], "%", reason: "IOAccelerator system-wide driver statistic") : Metric(.unavailable, "GPU統計が未公開、または複数GPUで集計未定義"), "温度": Metric(.waiting, "SMCセンサー取得待ち", unit: "°C")]
        if let device { m["統合メモリ"] = Metric(device.hasUnifiedMemory ? 1 : 0, "", reason: device.hasUnifiedMemory ? "あり" : "なし") }
        return Reading("gpu", "GPU", m, notes: [device?.name ?? "GPU基本情報取得不可", "使用率はシステム全体のドライバー統計。Metalは名称と基本情報だけに使用。統計の内部平均期間は非公開。"])
    }
}
