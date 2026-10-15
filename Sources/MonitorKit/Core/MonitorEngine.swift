import Foundation
/// All synchronous collectors run on the actor's executor, never on MainActor.
public actor MonitorEngine {
    private var cpu = CPUMonitor()
    private var network = NetworkMonitor()
    private var storage = StorageMonitor()
    private let memory = MemoryMonitor()
    private let gpu = GPUMonitor()
    private let battery = BatteryMonitor()
    private let sensors = SensorsMonitor()
    private var lastSlow: Double?
    private var slowReadings: [Reading] = []
    private var lastSample: Double?
    public init() {}
    public func reset() {
        cpu.reset(); network.reset(); storage.reset(); lastSample = nil; lastSlow = nil
    }
    public func sample(interface: String = "auto") -> Snapshot {
        let now = ProcessInfo.processInfo.systemUptime
        if let lastSample, now - lastSample > 30 || now <= lastSample { reset() }
        self.lastSample = now
        if lastSlow == nil || now - lastSlow! >= 5 {
            slowReadings = [battery.read(), sensors.read()]; lastSlow = now
        }
        var cpuReading = cpu.read(); var gpuReading = gpu.read()
        if let sensors = slowReadings.first(where: { $0.id == "sensors" }) {
            cpuReading.metrics["温度"] = sensors.metrics["CPU温度"]
            cpuReading.metrics["Pコア温度"] = sensors.metrics["CPU Pコア温度"]
            cpuReading.metrics["Eコア温度"] = sensors.metrics["CPU Eコア温度"]
            gpuReading.metrics["温度"] = sensors.metrics["GPU温度"]
        }
        return Snapshot(date: Date(), uptime: now, readings: [cpuReading, gpuReading, memory.read(), network.read(at: now, interface: interface), storage.read(at: now)] + slowReadings)
    }
}
