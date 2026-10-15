import Foundation
import IOKit
public struct StorageMonitor {
    private var readRates: [UInt64: CounterRate] = [:]
    private var writeRates: [UInt64: CounterRate] = [:]
    public init() {}
    public mutating func reset() { readRates = [:]; writeRates = [:] }
    public mutating func read(at time: Double) -> Reading {
        var m: [String: Metric] = [:]
        do {
            let values = try URL(fileURLWithPath: "/System/Volumes/Data").resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeLocalizedFormatDescriptionKey])
            if let total = values.volumeTotalCapacity, let free = values.volumeAvailableCapacity, total > 0, free <= total {
                m["総容量"] = Metric(Double(total), "B"); m["空き容量"] = Metric(Double(free), "B")
                m["使用容量（共有領域含む）"] = Metric(Double(total - free), "B"); m["使用率"] = Metric(Double(total - free) / Double(total) * 100, "%")
            } else { m["使用率"] = Metric(.unavailable, "容量キー不足") }
        } catch { m["使用率"] = Metric(.unavailable, "ボリューム容量取得失敗: \(error.localizedDescription)") }
        let devices = entries("IOBlockStorageDriver"); defer { devices.forEach { IOObjectRelease($0) } }
        var ids = Set<UInt64>(); var reads: [Metric] = []; var writes: [Metric] = []
        for device in devices {
            var id: UInt64 = 0
            guard IORegistryEntryGetRegistryEntryID(device, &id) == KERN_SUCCESS, ids.insert(id).inserted else { continue }
            guard let stats = property(device, "Statistics") as? [String: Any], let r = stats["Bytes (Read)"] as? NSNumber, let w = stats["Bytes (Write)"] as? NSNumber else {
                readRates[id] = nil; writeRates[id] = nil
                reads.append(Metric(.unavailable, "ドライバー統計不足")); writes.append(Metric(.unavailable, "ドライバー統計不足")); continue
            }
            var rr = readRates[id] ?? CounterRate(); var wr = writeRates[id] ?? CounterRate()
            let rv = rr.sample(r.uint64Value, at: time); let wv = wr.sample(w.uint64Value, at: time)
            readRates[id] = rr; writeRates[id] = wr; reads.append(rv); writes.append(wv)
            m["Disk \(id) 読込"] = rv; m["Disk \(id) 書込"] = wv
        }
        readRates = readRates.filter { ids.contains($0.key) }; writeRates = writeRates.filter { ids.contains($0.key) }
        func sum(_ values: [Metric]) -> Metric {
            guard !values.isEmpty else { return Metric(.unavailable, "IOBlockStorageDriver統計なし") }
            guard values.allSatisfy({ $0.value != nil }) else { return values.first { $0.value == nil }! }
            return Metric(values.compactMap(\.value).reduce(0,+), "B/s")
        }
        m["読込速度"] = sum(reads); m["書込速度"] = sum(writes)
        return Reading("storage", "Storage", m, notes: ["/System/Volumes/Data の総量−空き。APFS共有領域を含むため各volumeの使用量を加算しない。purgeableの将来回収可能量は空きに加えない。", "I/O: IOBlockStorageDriver \(ids.count)件をRegistry IDで一意化。接続中の物理・仮想ブロックドライバーを含む論理I/O合計。内部SSD単独の物理転送速度ではない。APFS子統計は加算しない。"])
    }
}
