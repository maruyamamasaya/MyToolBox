import Foundation
import MonitorKit
@main struct Probe {
    static func main() async throws {
        let engine = MonitorEngine()
        let count = min(600, max(2, Int(CommandLine.arguments.dropFirst().first ?? "3") ?? 3))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        for i in 0..<count {
            let result = await engine.sample(interface: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "auto")
            print(String(decoding: try encoder.encode(result), as: UTF8.self)); fflush(stdout)
            if i < count - 1 { try await Task.sleep(nanoseconds: 1_000_000_000) }
        }
    }
}
