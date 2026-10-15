import Foundation
public struct MemoryMonitor {
    public init() {}
    /// Complement of the same estimated used value shown in the percentage.
    public static func available(total: Metric, used: Metric) -> Metric {
        guard total.state == .available, used.state == .available,
              let t = total.value, let u = used.value, total.unit == "B", used.unit == "B",
              t.isFinite, u.isFinite, t > 0, u >= 0, u <= t else {
            return Metric(.unavailable, "総容量／推定使用容量が取得不可または不整合", unit: "B")
        }
        return Metric(t - u, "B", reason: "総容量−使用容量（推定）。即時未使用のfreeとは異なる")
    }
    public func read() -> Reading {
        var vm = vm_statistics64(); var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &vm) { pointer in pointer.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { host_statistics64(monitoringHost, HOST_VM_INFO64, $0, &size) } }
        guard status == KERN_SUCCESS else { return Reading("memory", "Memory", ["使用率": Metric(.unavailable, "host_statistics64: \(status)")]) }
        let page = Double(vm_kernel_page_size)
        var m: [String: Metric] = ["空き（free）": Metric(Double(vm.free_count) * page, "B"), "キャッシュ（file-backed）": Metric(Double(vm.external_page_count) * page, "B"), "圧縮（物理）": Metric(Double(vm.compressor_page_count) * page, "B"), "回収可能（purgeable）": Metric(Double(vm.purgeable_count) * page, "B")]
        // Approximate Activity Monitor's physical used memory; never count compressed logical pages.
        let usedPages = Double(vm.active_count) + Double(vm.inactive_count) + Double(vm.wire_count) + Double(vm.compressor_page_count) - Double(vm.external_page_count) - Double(vm.purgeable_count)
        let used = usedPages * page
        m["使用容量（推定）"] = used >= 0 ? Metric(used, "B", reason: "active+inactive+wired+compressor−external−purgeable") : Metric(.unavailable, "VM統計の分類不整合")
        if let total = sysValue("hw.memsize", UInt64(0)), total > 0 {
            m["総容量"] = Metric(Double(total), "B"); m["使用率"] = used >= 0 && used <= Double(total) ? Metric(used / Double(total) * 100, "%", reason: "物理使用容量の推定") : Metric(.unavailable, "VM統計の分類不整合")
        } else { m["使用率"] = Metric(.unavailable, "hw.memsize読取失敗"); m["総容量"] = Metric(.unavailable, "hw.memsize読取失敗") }
        m["利用可能容量（推定）"] = Self.available(total: m["総容量"] ?? Metric(.unavailable, "総容量なし"), used: m["使用容量（推定）"] ?? Metric(.unavailable, "使用容量なし"))
        if let swap = sysValue("vm.swapusage", xsw_usage()) { m["スワップ使用"] = Metric(Double(swap.xsu_used), "B"); m["スワップ総量"] = Metric(Double(swap.xsu_total), "B") }
        else { m["スワップ使用"] = Metric(.unavailable, "vm.swapusage読取失敗") }
        let pressure = sysValue("kern.memorystatus_vm_pressure_level", Int32(0))
        let label = pressure.flatMap { [1: "正常", 2: "警告", 4: "危険"][Int($0)] }
        m["プレッシャー"] = label.map { Metric(Double(pressure!), "", reason: $0) } ?? Metric(.unavailable, "OS pressure level未取得／未知")
        return Reading("memory", "Memory", m, notes: ["freeは即時未使用ページ。キャッシュはfile-backedで回収可能、purgeableと重複し得るため合算しない。圧縮は圧縮後の物理ページ。", "使用容量は推定式。Activity Monitorと一致を保証しない。pressureはOSレベル値、RAM使用率から推測しない。"])
    }
}
