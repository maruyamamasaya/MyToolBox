import Foundation
import IOKit

// Read-only reimplementation of the AppleSMC 80-byte ABI.
// Protocol and M1 key reference: exelban/stats (MIT), revision c9e7ebe3390a84e3075946ffe39dda709c4747b1.
// Attribution and license: Resources/Stats-LICENSE.txt. No fan-control/write operations exist here.
enum SMCFailure: Error, CustomStringConvertible {
    case message(String)
    var description: String { switch self { case let .message(text): return text } }
}
enum SMCReadCommand: UInt8 { case info = 9, value = 5 }
enum SMCCodec {
    static func uint32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        (0..<4).reduce(0) { $0 | UInt32(bytes[offset + $1]) << ($1 * 8) }
    }
    static func request(key: String, command: SMCReadCommand, size: UInt32 = 0) throws -> [UInt8] {
        guard key.utf8.count == 4, key.utf8.allSatisfy({ $0 < 128 }), size <= 32 else { throw SMCFailure.message("SMC要求形式不正") }
        var bytes = [UInt8](repeating: 0, count: 80)
        let code = key.utf8.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        for i in 0..<4 { bytes[i] = UInt8(truncatingIfNeeded: code >> (i * 8)); bytes[28 + i] = UInt8(truncatingIfNeeded: size >> (i * 8)) }
        bytes[42] = command.rawValue
        return bytes
    }
    static func check(_ bytes: [UInt8]) throws {
        guard bytes.count == 80 else { throw SMCFailure.message("SMC応答サイズ不一致") }
        guard bytes[40] == 0 else { throw SMCFailure.message("SMC result=0x\(String(bytes[40], radix: 16))") }
    }
    static func metadata(_ bytes: [UInt8]) throws -> (Int, String) {
        try check(bytes)
        let size = Int(uint32(bytes, at: 28)); let code = uint32(bytes, at: 32)
        guard size > 0 && size <= 32 else { throw SMCFailure.message("SMCデータ長不正: \(size)") }
        let type = String(bytes: [24,16,8,0].map { UInt8(truncatingIfNeeded: code >> $0) }, encoding: .ascii) ?? ""
        return (size, type)
    }
    static func decode(_ bytes: [UInt8], type: String) throws -> Double {
        let value: Double
        switch (type, bytes.count) {
        case ("flt ", 4): value = Double(Float(bitPattern: uint32(bytes, at: 0)))
        case ("sp78", 2): value = Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
        case ("fpe2", 2): value = Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        case ("ui8 ", 1): value = Double(bytes[0])
        case ("ui16", 2): value = Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case ("ui32", 4): value = Double(bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) })
        default: throw SMCFailure.message("SMC未対応型／サイズ: \(type), \(bytes.count)")
        }
        guard value.isFinite else { throw SMCFailure.message("SMC非有限値") }
        return value
    }
}
final class SMCReader {
    private var connection: io_connect_t = 0
    init() throws {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { throw SMCFailure.message("AppleSMCサービスなし") }
        defer { IOObjectRelease(service) }
        let status = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard status == KERN_SUCCESS else { throw SMCFailure.message("AppleSMC読取接続拒否: \(status)") }
    }
    deinit { if connection != 0 { IOServiceClose(connection) } }
    private func call(key: String, command: SMCReadCommand, size: UInt32 = 0) throws -> [UInt8] {
        let input = try SMCCodec.request(key: key, command: command, size: size)
        var output = [UInt8](repeating: 0, count: 80); var outputSize = 80
        let status = input.withUnsafeBytes { source in
            output.withUnsafeMutableBytes { destination in
                IOConnectCallStructMethod(connection, 2, source.baseAddress, 80, destination.baseAddress, &outputSize)
            }
        }
        guard status == KERN_SUCCESS else { throw SMCFailure.message("SMC \(key) IOエラー: \(status)") }
        guard outputSize == 80 else { throw SMCFailure.message("SMC \(key) 応答サイズ: \(outputSize)") }
        try SMCCodec.check(output)
        return output
    }
    func read(_ key: String) throws -> (value: Double, type: String) {
        let (size, type) = try SMCCodec.metadata(call(key: key, command: .info))
        let bytes = try call(key: key, command: .value, size: UInt32(size))
        return (try SMCCodec.decode(Array(bytes[48..<(48 + size)]), type: type), type)
    }
}
