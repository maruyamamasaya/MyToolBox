import Foundation
import Darwin

public enum NetworkBuilders {
    public typealias Failure = EverydayCalculators.Failure
    public struct Subnet {
        public let input: String
        public let address: UInt32
        public let prefix: Int
        public let mask: UInt32
        public let network: UInt32
        public let broadcast: UInt32
        public var total: UInt64 { UInt64(broadcast) - UInt64(network) + 1 }
        public var hosts: UInt64 { prefix >= 31 ? total : total - 2 }
        public var first: UInt32 { prefix >= 31 ? network : network + 1 }
        public var last: UInt32 { prefix >= 31 ? broadcast : broadcast - 1 }
        public var cidr: String { NetworkBuilders.ip(network) + "/\(prefix)" }
        public var rows: [(String, String)] {
            [("入力", input), ("サブネットマスク", NetworkBuilders.ip(mask)), ("ネットワーク", cidr), ("利用可能IP開始", NetworkBuilders.ip(first)), ("利用可能IP終了", NetworkBuilders.ip(last)), ("ブロードキャスト", NetworkBuilders.ip(broadcast)), ("総IP数", String(total)), ("利用可能ホスト数", String(hosts))]
        }
    }
    public static func ipv4(_ text: String) -> UInt32? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard !part.isEmpty, part.count <= 3, part.allSatisfy({ $0.isASCII && $0.isNumber }), let n = UInt32(part), n <= 255 else { return nil }
            value = value << 8 | n
        }; return value
    }
    public static func ip(_ value: UInt32) -> String { [24, 16, 8, 0].map { String((value >> $0) & 255) }.joined(separator: ".") }
    public static func subnet(_ text: String) throws -> Subnet {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "/", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let address = ipv4(parts[0]), !parts[1].isEmpty, parts[1].allSatisfy({ $0.isASCII && $0.isNumber }), let prefix = Int(parts[1]), (0...32).contains(prefix) else { throw Failure.invalid("IPv4/CIDR（/0〜/32）で入力してください。") }
        let mask: UInt32 = prefix == 0 ? 0 : UInt32.max << (32 - prefix)
        let network = address & mask
        return Subnet(input: ip(address) + "/\(prefix)", address: address, prefix: prefix, mask: mask, network: network, broadcast: network | ~mask)
    }
    public static func formatCIDR(_ text: String) -> String {
        text.components(separatedBy: .newlines).map { line in
            let parts = line.replacingOccurrences(of: "/", with: " ").split(whereSeparator: { $0.isWhitespace })
            return parts.count == 2 ? parts.joined(separator: "/") : line.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }.joined(separator: "\n")
    }
    public struct Analysis {
        public let subnets: [Subnet]
        public let errors: [String]
        public let groups: [String]
        public let relations: [String]
    }
    public static func analyze(_ text: String) throws -> Analysis {
        guard text.utf8.count <= 100_000 else { throw Failure.invalid("入力は100KB以内にしてください。") }
        let lines = text.components(separatedBy: .newlines)
        guard lines.count <= 1000 else { throw Failure.invalid("入力は1,000行以内にしてください。") }
        var subnets: [Subnet] = [], errors: [String] = []
        for (i, line) in lines.enumerated() where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            do { subnets.append(try subnet(line)) } catch { errors.append("\(i + 1)行目: \(line) — \(error.localizedDescription)") }
        }
        let grouped = Dictionary(grouping: subnets, by: { $0.cidr })
        let groups = grouped.keys.sorted().map { "\($0): " + grouped[$0]!.map { ip($0.address) }.joined(separator: ", ") }
        let unique = grouped.keys.sorted().compactMap { grouped[$0]?.first }
        // Only show the nearest enclosing network, avoiding redundant transitive pairs.
        var relations: [String] = []
        for child in unique {
            let parent = unique.filter { $0.prefix < child.prefix && $0.network <= child.network && $0.broadcast >= child.broadcast }.max { $0.prefix < $1.prefix }
            if let parent { relations.append(parent.cidr + " ⊃ " + child.cidr) }
        }
        return Analysis(subnets: subnets, errors: errors, groups: groups, relations: relations)
    }
    public static let recordTypes = ["A", "AAAA", "CNAME", "MX", "TXT"]
    private static func domain(_ text: String, owner: Bool) -> Bool {
        if owner && text == "@" { return true }
        let trimmed = text.hasSuffix(".") ? String(text.dropLast()) : text
        guard !trimmed.isEmpty, trimmed.utf8.count <= 253 else { return false }
        let labels = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        return labels.enumerated().allSatisfy { index, label in
            if owner && index == 0 && label == "*" { return true }
            guard !label.isEmpty, label.utf8.count <= 63, label.first != "-", label.last != "-" else { return false }
            return label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || (owner && $0 == "_")) }
        }
    }
    public static func record(type: String, host: String, ttl: String, value: String, priority: String) throws -> String {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = type == "TXT" ? value : value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard recordTypes.contains(type), domain(host, owner: true) else { throw Failure.invalid("ホスト名を確認してください（日本語ドメインはPunycodeで入力）。") }
        guard !ttl.isEmpty, ttl.allSatisfy({ $0.isASCII && $0.isNumber }), let seconds = UInt32(ttl), seconds <= 2_147_483_647 else { throw Failure.invalid("TTLは0〜2147483647の整数です。") }
        let data: String
        switch type {
        case "A": guard let address = ipv4(value) else { throw Failure.invalid("IPv4アドレスを確認してください。") }; data = ip(address)
        case "AAAA":
            var address = in6_addr()
            guard inet_pton(AF_INET6, value, &address) == 1 else { throw Failure.invalid("IPv6アドレスを確認してください。") }; data = value
        case "CNAME", "MX":
            guard domain(value, owner: false) else { throw Failure.invalid("宛先ドメイン名を確認してください。") }
            let fqdn = value.hasSuffix(".") ? value : value + "."
            if type == "MX" {
                guard !priority.isEmpty, priority.allSatisfy({ $0.isASCII && $0.isNumber }), let p = UInt16(priority) else { throw Failure.invalid("MX優先度は0〜65535です。") }; data = "\(p) \(fqdn)"
            } else { data = fqdn }
        default:
            guard !value.isEmpty, value.utf8.count <= 4096, !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw Failure.invalid("TXTは制御文字なし・1〜4096バイトで入力してください。") }
            var chunks: [String] = [], chunk = "", bytes = 0
            for char in value {
                let n = String(char).utf8.count
                guard n <= 255 else { throw Failure.invalid("TXTの1文字が255バイトを超えています。") }
                if bytes + n > 255 { chunks.append(chunk); chunk = ""; bytes = 0 }
                chunk.append(char); bytes += n
            }; chunks.append(chunk)
            data = chunks.map { "\"" + $0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"" }.joined(separator: " ")
        }
        return "\(host)\t\(seconds)\tIN\t\(type)\t\(data)"
    }
}
