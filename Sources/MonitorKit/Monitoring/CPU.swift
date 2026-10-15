import Foundation
public struct CPUMonitor {
    private var ticks = CPUTicks()
    private var mapping: [Int: String]?
    public init() {}
    public mutating func reset() { ticks.reset(); mapping = nil }
    public mutating func read() -> Reading {
        var count: natural_t = 0; var info: processor_info_array_t?; var size: mach_msg_type_number_t = 0
        let result = host_processor_info(monitoringHost, PROCESSOR_CPU_LOAD_INFO, &count, &info, &size)
        guard result == KERN_SUCCESS, let info else { ticks.reset(); return Reading("cpu", "CPU", ["使用率": Metric(.unavailable, "host_processor_info: \(result)")]) }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(size) * vm_size_t(MemoryLayout<integer_t>.size)) }
        let raw = (0..<Int(count)).map { i in (0..<4).map { UInt32(bitPattern: info[i * 4 + $0]) } }
        let values = ticks.sample(raw)
        func average(_ indices: [Int]) -> Metric {
            let v = indices.compactMap { values[$0].value }
            guard !indices.isEmpty else { return Metric(.unavailable, "CPUトポロジー未確認") }
            guard v.count == indices.count else { return Metric(.waiting, "CPU tick差分待ち") }
            return Metric(v.reduce(0,+) / Double(v.count), "%")
        }
        if mapping == nil { mapping = topology() }
        let mapping = self.mapping ?? [:]
        let validMap = mapping.count == Int(count) && Set(mapping.keys) == Set(0..<Int(count))
        var m: [String: Metric] = ["使用率": average(Array(values.indices)), "論理コア数": Metric(Double(count)), "温度": Metric(.waiting, "SMCセンサー取得待ち", unit: "°C")]
        for type in ["P", "E"] {
            let indices = validMap ? values.indices.filter { mapping[$0] == type } : []
            m[type + "コア使用率"] = average(indices)
            m[type + "コア数"] = validMap ? Metric(Double(indices.count)) : Metric(.unavailable, "トポロジーの完全な対応を確認できない")
        }
        for i in values.indices { m["Core \(i) (\(validMap ? mapping[i]! : "不明"))"] = values[i] }
        return Reading("cpu", "CPU", m, notes: [sysString("machdep.cpu.brand_string") ?? "チップ名取得不可", "user+system+nice ticks / 全ticks。全体は各コアの等重み平均、最大100%。", "P/E対応: IODeviceTree logical-cpu-id + cluster-type（非公開の機種依存情報）。"])
    }
}
