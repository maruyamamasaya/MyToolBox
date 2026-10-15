import Foundation
import SystemConfiguration

public struct NetworkMonitor {
    private var rates = InterfaceRates()
    public init() {}
    public mutating func reset() { rates.reset() }
    public mutating func read(at time: Double, interface requested: String) -> Reading {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]; var size = 0
        guard sysctl(&mib, 6, nil, &size, nil, 0) == 0, size > 0 else { reset(); return failure("NET_RT_IFLIST2サイズ取得失敗") }
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<if_msghdr2>.alignment)
        defer { buffer.deallocate() }
        guard sysctl(&mib, 6, buffer, &size, nil, 0) == 0 else { reset(); return failure("NET_RT_IFLIST2読取失敗") }
        var interfaces: [String: (UInt64, UInt64, Bool, UInt16)] = [:]; var offset = 0
        while offset + MemoryLayout<if_msghdr>.size <= size {
            let header = buffer.advanced(by: offset).load(as: if_msghdr.self)
            let length = Int(header.ifm_msglen)
            guard length > 0, offset + length <= size else { break }
            if header.ifm_type == RTM_IFINFO2, length >= MemoryLayout<if_msghdr2>.size {
                let h = buffer.advanced(by: offset).load(as: if_msghdr2.self)
                var name = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                if if_indextoname(UInt32(h.ifm_index), &name) != nil {
                    interfaces[String(cString: name)] = (h.ifm_data.ifi_ibytes, h.ifm_data.ifi_obytes, h.ifm_flags & IFF_UP != 0 && h.ifm_flags & IFF_RUNNING != 0, h.ifm_index)
                }
            }
            offset += length
        }
        let store = SCDynamicStoreCreate(nil, "MyToolBox" as CFString, nil, nil)
        var primary: String?
        if let store {
            for family in ["IPv4", "IPv6"] {
                if let state = SCDynamicStoreCopyValue(store, "State:/Network/Global/\(family)" as CFString) as? [String: Any], let name = state["PrimaryInterface"] as? String { primary = name; break }
            }
        }
        let name = requested == "auto" ? primary : requested
        let listing = interfaces.keys.sorted().map { "\($0): \(interfaces[$0]!.2 ? "up/running" : "down")" }.joined(separator: ", ")
        guard let name, let data = interfaces[name] else { reset(); return Reading("network", "Network", ["受信速度": Metric(.unavailable, "選択IF／デフォルト経路なし"), "送信速度": Metric(.unavailable, "選択IF／デフォルト経路なし")], notes: [listing]) }
        guard data.2 else { reset(); return Reading("network", "Network", ["受信速度": Metric(.unavailable, "\(name) はdown"), "送信速度": Metric(.unavailable, "\(name) はdown")], notes: [listing]) }
        let (rx, tx) = rates.sample(identity: "\(name):\(data.3)", received: data.0, sent: data.1, at: time)
        return Reading("network", "Network", ["受信速度": rx, "送信速度": tx, "累積受信": Metric(Double(data.0), "B"), "累積送信": Metric(Double(data.1), "B")], notes: ["選択: \(name)（up/running、インターネット疎通は検査しない）", listing, "単一IFのみ。VPN/bridge/物理IFを合算しない。累積はOSのIF生成／リセット以降（開始時刻は取得不可）。64-bit if_data64。"])
    }
    private func failure(_ reason: String) -> Reading { Reading("network", "Network", ["受信速度": Metric(.unavailable, reason), "送信速度": Metric(.unavailable, reason)]) }
}
