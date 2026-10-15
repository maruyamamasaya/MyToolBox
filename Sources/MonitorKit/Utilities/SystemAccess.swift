import Foundation
import IOKit

let monitoringHost = mach_host_self()

func sysValue<T>(_ name: String, _ seed: T) -> T? {
    var value = seed; var size = MemoryLayout<T>.size
    let result = withUnsafeMutableBytes(of: &value) { sysctlbyname(name, $0.baseAddress, &size, nil, 0) }
    guard result == 0, size == MemoryLayout<T>.size else { return nil }
    return value
}
func sysString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var bytes = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
    return String(cString: bytes)
}
func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
    IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
}
func entries(_ className: String) -> [io_registry_entry_t] {
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else { return [] }
    defer { IOObjectRelease(iterator) }
    var result: [io_registry_entry_t] = []
    while case let item = IOIteratorNext(iterator), item != 0 { result.append(item) }
    return result
}
func number(_ dictionary: [String: Any], _ key: String, unit: String = "") -> Metric {
    guard let n = dictionary[key] as? NSNumber else { return Metric(.unavailable, "IORegistryキー \(key) が存在しない", unit: unit) }
    return Metric(n.doubleValue, unit)
}
func topology() -> [Int: String] {
    var iterator: io_iterator_t = 0
    guard IORegistryCreateIterator(kIOMainPortDefault, "IODeviceTree", IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else { return [:] }
    defer { IOObjectRelease(iterator) }
    var result: [Int: String] = [:]
    while case let entry = IOIteratorNext(iterator), entry != 0 {
        defer { IOObjectRelease(entry) }
        if let id = property(entry, "logical-cpu-id") as? NSNumber,
           let data = property(entry, "cluster-type") as? Data,
           let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters), ["P", "E"].contains(text) { result[id.intValue] = text }
    }
    return result
}
