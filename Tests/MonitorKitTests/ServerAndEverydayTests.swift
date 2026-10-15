import XCTest
@testable import MonitorKit

final class ServerAndEverydayTests: XCTestCase {
    func testCIDRBoundariesAndMixedInput() throws {
        let normal = try NetworkBuilders.subnet("192.168.1.10/24")
        XCTAssertEqual(normal.cidr, "192.168.1.0/24"); XCTAssertEqual(normal.hosts, 254)
        XCTAssertEqual(NetworkBuilders.ip(normal.first), "192.168.1.1"); XCTAssertEqual(NetworkBuilders.ip(normal.last), "192.168.1.254")
        let zero = try NetworkBuilders.subnet("0.0.0.0/0")
        XCTAssertEqual(zero.total, 4_294_967_296); XCTAssertEqual(zero.hosts, 4_294_967_294)
        for (input, hosts) in [("192.0.2.0/31",UInt64(2)),("192.0.2.7/32",1)] { XCTAssertEqual(try NetworkBuilders.subnet(input).hosts, hosts) }
        for bad in ["256.1.1.1/24","::1/64","1.2.3.4/33","1.2.3.4/-1","1.2.3/24"] { XCTAssertThrowsError(try NetworkBuilders.subnet(bad)) }
        let result = try NetworkBuilders.analyze("192.168.1.1/16\n192.168.1.1/20\n192.168.1.2/24\n192.168.1.3/24\nbad")
        XCTAssertEqual(result.subnets.count, 4); XCTAssertEqual(result.errors.count, 1); XCTAssertEqual(result.groups.count, 3); XCTAssertEqual(result.relations.count, 2)
        XCTAssertEqual(NetworkBuilders.formatCIDR("192.168.1.10 / 24\n192.0.2.1 32"), "192.168.1.10/24\n192.0.2.1/32")
        XCTAssertThrowsError(try NetworkBuilders.analyze(String(repeating: "\n", count: 1001)))
        let windowsLines = Array(repeating: "192.0.2.1/32", count: 1000).joined(separator: "\r\n")
        XCTAssertEqual(try NetworkBuilders.analyze(windowsLines).subnets.count, 1000)
    }
    func testDNSValidationAndEscaping() throws {
        func record(_ type: String, _ value: String, host: String = "@", ttl: String = "3600", priority: String = "10") throws -> String {
            try NetworkBuilders.record(type: type, host: host, ttl: ttl, value: value, priority: priority)
        }
        XCTAssertEqual(try record("A", "192.0.2.1"), "@\t3600\tIN\tA\t192.0.2.1")
        XCTAssertTrue(try record("MX", "example.com", priority: "65535").hasSuffix("65535 example.com."))
        XCTAssertTrue(try record("CNAME", "example.com.", host: "www").hasSuffix("example.com."))
        XCTAssertNoThrow(try record("AAAA", "::ffff:192.0.2.1"))
        for value in ["broken:::", "256.1.1.1"] { XCTAssertThrowsError(try record("AAAA", value)) }
        for ttl in ["-1","1.2","2147483648",""] { XCTAssertThrowsError(try record("A", "192.0.2.1", ttl: ttl)) }
        for host in ["a\tb","a\nb","bad..example","-bad",String(repeating: "a", count: 64)] { XCTAssertThrowsError(try record("A", "192.0.2.1", host: host)) }
        XCTAssertEqual(try record("TXT", " a\"b\\c; "), "@\t3600\tIN\tTXT\t\" a\\\"b\\\\c; \"")
        XCTAssertTrue(try record("TXT", String(repeating: "あ", count: 86)).contains("\" \""))
        XCTAssertThrowsError(try record("TXT", "line\nbreak"))
        XCTAssertThrowsError(try record("MX", "example.com", priority: "65536"))
    }
    func testAllUnitGroupsRoundTripAndKnownValues() throws {
        for (group, entry) in EverydayCalculators.unitGroups.enumerated() {
            for unit in entry.units {
                let first = entry.units[0].0
                let converted = try EverydayCalculators.convert(100, group: group, from: unit.0, to: first, rate: 2)
                let restored = try EverydayCalculators.convert(converted, group: group, from: first, to: unit.0, rate: 0.5)
                XCTAssertEqual(restored, 100, accuracy: 0.000001, "\(entry.name) \(unit.0)")
            }
        }
        XCTAssertEqual(try EverydayCalculators.convert(1, group: 0, from: "inch", to: "cm"), 2.54, accuracy: 1e-10)
        XCTAssertEqual(try EverydayCalculators.convert(0, group: 4, from: "℃", to: "℉"), 32)
        XCTAssertEqual(try EverydayCalculators.convert(0, group: 4, from: "℃", to: "K"), 273.15)
        XCTAssertThrowsError(try EverydayCalculators.convert(-1, group: 4, from: "K", to: "℃"))
        XCTAssertEqual(try EverydayCalculators.convert(1, group: 5, from: "KB", to: "B", binary: false), 1000)
        XCTAssertEqual(try EverydayCalculators.convert(1, group: 5, from: "KB", to: "B", binary: true), 1024)
        XCTAssertThrowsError(try EverydayCalculators.convert(2, group: 9, from: "USD", to: "JPY"))
        XCTAssertEqual(try EverydayCalculators.convert(2, group: 9, from: "USD", to: "JPY", rate: 150), 300)
    }
    func testPercentagesAndArithmeticFailures() throws {
        XCTAssertEqual(try EverydayCalculators.percentage(.change, a: 1000, b: 1250).map(\.1), [25,250,125,1.25])
        XCTAssertEqual(try EverydayCalculators.percentage(.reverse, a: 20, b: 12000)[0].1, 10000)
        XCTAssertThrowsError(try EverydayCalculators.percentage(.ratio, a: 0, b: 1))
        XCTAssertThrowsError(try EverydayCalculators.percentage(.reverse, a: -100, b: 1))
        for (input, expected) in [("1000 + 250 × 2",1500.0),("(1000+250)*2",2500),("8/4/2",1),("10-3-2",5),("-2*-3",6),("1e-3+2",2.001)] {
            XCTAssertEqual(try EverydayCalculators.expression(input), expected, accuracy: 1e-10)
        }
        for bad in ["1/0","0/0","(1+2","1;2","sin(1)","2(3)","1e309",String(repeating: "-", count: 100)+"1"] { XCTAssertThrowsError(try EverydayCalculators.expression(bad)) }
        XCTAssertEqual(try EverydayCalculators.number("1,234.5"),1234.5)
        XCTAssertThrowsError(try EverydayCalculators.number("12,34"))
        XCTAssertEqual(try EverydayCalculators.percentageNumber("￥１,０００円"),1000)
    }
    func testNumericSummaryAndIgnoredValues() throws {
        let result = try EverydayCalculators.summarize("11 19 38 42 46 invalid NaN Infinity")
        let rows = Dictionary(uniqueKeysWithValues: result.rows)
        XCTAssertEqual(rows["合計"],156); XCTAssertEqual(rows["平均"],31.2); XCTAssertEqual(rows["中央値"],38); XCTAssertEqual(result.ignored.count,3)
        XCTAssertEqual(try EverydayCalculators.summarize("1,2,3,4").rows.first { $0.0 == "中央値" }?.1, 2.5)
        XCTAssertThrowsError(try EverydayCalculators.summarize("NaN"))
        XCTAssertThrowsError(try EverydayCalculators.summarize("1e308 1e308"))
    }
    func testEveryPermissionRoundTrip() throws {
        for value in 0...0o7777 {
            let permission = try ServerUtilities.permission(String(format: "%04o", value))
            XCTAssertEqual(try ServerUtilities.permission(permission.symbolic).value, value)
        }
        XCTAssertEqual(try ServerUtilities.permission("755").symbolic, "rwxr-xr-x")
        for invalid in ["888","-1","rwt------","rwxrwxrwz"] { XCTAssertThrowsError(try ServerUtilities.permission(invalid)) }
    }
    func testCronAndEpochDates() throws {
        let zone = TimeZone(identifier: "Asia/Tokyo")!
        let start = try ServerUtilities.date("2026-10-15 08:59:00", timeZone: zone)
        let next = try ServerUtilities.cron("0 9 * * 1-5").next(after: start, timeZone: zone)
        XCTAssertEqual(ServerUtilities.dateText(next[0], timeZone: zone), "2026-10-15 09:00:00 +09:00")
        XCTAssertEqual(try ServerUtilities.cron("*/5 * * * *").values[0].count,12)
        for invalid in ["60 * * * *","*/0 * * * *","0 0 * * 7","0 0 * *","0 0 32 * *","1,,2 * * * *"] { XCTAssertThrowsError(try ServerUtilities.cron(invalid)) }
        XCTAssertEqual(try ServerUtilities.epoch("1000000000000", unit: .automatic).timeIntervalSince1970, 1e9)
        XCTAssertEqual(try ServerUtilities.epoch("-1", unit: .seconds).timeIntervalSince1970,-1)
        XCTAssertThrowsError(try ServerUtilities.date("2026-02-30 12:00:00", timeZone: zone))
        XCTAssertThrowsError(try ServerUtilities.epoch("1e20", unit: .seconds))
    }
    func testDirectoryExchangeAndInvalidHierarchy() throws {
        let nodes = DirectoryTree.sample
        XCTAssertEqual(try DirectoryTree.decode(DirectoryTree.encode(nodes)), nodes)
        let imported = try DirectoryTree.decode(DirectoryTree.encodeReference(nodes))
        XCTAssertEqual(imported.map(\.name), nodes.map(\.name)); XCTAssertEqual(imported.map(\.depth),nodes.map(\.depth))
        var style = DirectoryTree.Style(); style.emoji = false
        let rendered = try DirectoryTree.render(nodes, format: .tree, style: style)
        XCTAssertEqual(try DirectoryTree.parse(rendered).map(\.name), nodes.map(\.name))
        for format in DirectoryTree.Format.allCases { XCTAssertFalse(try DirectoryTree.render(nodes, format: format).isEmpty) }
        XCTAssertThrowsError(try DirectoryTree.validate([.init(name: "bad", depth: 1)]))
        XCTAssertThrowsError(try DirectoryTree.validate([.init(name: "file", folder: false), .init(name: "child", depth: 1)]))
        XCTAssertThrowsError(try DirectoryTree.decode("[]bad"))
        XCTAssertEqual(Set(CommandReference.entries.map(\.name)).count,CommandReference.entries.count)
        XCTAssertGreaterThanOrEqual(CommandReference.entries.count,165)
        XCTAssertTrue(CommandReference.entries.contains { $0.name == "grep" && $0.matches("grep") })
    }
}
