import Foundation

public enum Availability: String, Codable, Sendable { case available, waiting, unavailable, notPresent }
public struct Metric: Codable, Sendable, Equatable {
    public var value: Double?
    public var unit: String
    public var state: Availability
    public var reason: String
    public init(_ value: Double, _ unit: String = "", reason: String = "") {
        self.value = value.isFinite ? value : nil; self.unit = unit
        state = value.isFinite ? .available : .unavailable
        self.reason = value.isFinite ? reason : "非有限値"
    }
    public init(_ state: Availability, _ reason: String, unit: String = "") {
        value = nil; self.state = state; self.reason = reason; self.unit = unit
    }
}
public struct Reading: Codable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var metrics: [String: Metric]
    public var notes: [String]
    public init(_ id: String, _ title: String, _ metrics: [String: Metric], notes: [String] = []) {
        self.id = id; self.title = title; self.metrics = metrics; self.notes = notes
    }
}
public struct Snapshot: Codable, Sendable {
    public var date: Date
    public var uptime: Double
    public var readings: [Reading]
    public func metric(_ section: String, _ name: String) -> Metric? {
        readings.first { $0.id == section }?.metrics[name]
    }
}
public struct HistoryPoint: Identifiable, Sendable {
    public let id = UUID()
    public var date: Date
    public var uptime: Double
    public var values: [String: Double]
    public var segment: Int
}
public struct History: Sendable {
    public private(set) var points: [HistoryPoint] = []
    private var segment = 0
    public init() {}
    public mutating func breakSegment() { segment += 1 }
    public mutating func append(_ snapshot: Snapshot) {
        if let last = points.last, snapshot.date <= last.date || snapshot.uptime - last.uptime > 10 { breakSegment() }
        let pairs = [("cpu", "使用率"), ("gpu", "使用率"), ("memory", "使用率"), ("network", "受信速度"), ("network", "送信速度")]
        var values: [String: Double] = [:]
        for (s, m) in pairs { if let v = snapshot.metric(s, m)?.value { values[s + "." + m] = v } }
        if values.count != pairs.count { breakSegment() }
        points.append(HistoryPoint(date: snapshot.date, uptime: snapshot.uptime, values: values, segment: segment))
        points.removeAll { snapshot.uptime - $0.uptime > 60 }
    }
}

/// Counter windows use monotonic time; missing/reset observations never become zero rates.
public struct CounterRate: Sendable {
    private var baseline: (UInt64, Double)?
    public init() {}
    public mutating func reset() { baseline = nil }
    public mutating func sample(_ count: UInt64, at time: Double) -> Metric {
        defer { baseline = (count, time) }
        guard let (old, then) = baseline else { return Metric(.waiting, "差分の初回サンプル待ち", unit: "B/s") }
        guard time > then, time - then <= 30, count >= old else {
            return Metric(.waiting, "カウンターリセット／計測間隔の中断", unit: "B/s")
        }
        return Metric(Double(count - old) / (time - then), "B/s")
    }
}
public struct CPUTicks: Sendable {
    private var previous: [[UInt32]]?
    public init() {}
    public mutating func reset() { previous = nil }
    public mutating func sample(_ ticks: [[UInt32]]) -> [Metric] {
        defer { previous = ticks }
        guard let old = previous, old.count == ticks.count else {
            return ticks.map { _ in Metric(.waiting, "CPU差分の初回サンプル待ち", unit: "%") }
        }
        return zip(old, ticks).map { a, b in
            guard a.count == 4, b.count == 4, zip(a,b).allSatisfy({ $1 >= $0 }) else { return Metric(.waiting, "CPU tickリセット") }
            let d = zip(a,b).map { Double($1 - $0) }; let total = d.reduce(0,+)
            guard total > 0 else { return Metric(.waiting, "CPU tick未更新") }
            return Metric((total - d[2]) / total * 100, "%")
        }
    }
}

/// Keeps a single interface baseline; changing identity or losing the interface resets both directions.
public struct InterfaceRates: Sendable {
    private var identity: String?
    private var received = CounterRate()
    private var sent = CounterRate()
    public init() {}
    public mutating func reset() { identity = nil; received.reset(); sent.reset() }
    public mutating func sample(identity next: String, received rx: UInt64, sent tx: UInt64, at time: Double) -> (Metric, Metric) {
        if identity != next { reset(); identity = next }
        return (received.sample(rx, at: time), sent.sample(tx, at: time))
    }
}
