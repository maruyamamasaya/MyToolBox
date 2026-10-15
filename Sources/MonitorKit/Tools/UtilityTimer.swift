import Foundation

/// Elapsed time derives from dates, rather than counting UI refreshes; sleep counts as elapsed time.
public struct UtilityTimer: Codable, Identifiable {
    public var id = UUID()
    public var name = "タイマー"
    public var countdown = true
    public var duration: Double = 300
    public var elapsed: Double = 0
    public var startedAt: Date?
    public var note = ""
    public var alerts = true
    public var warningSeconds = 10
    public init() {}
    public func elapsed(at now: Date) -> Double { elapsed + (startedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0) }
    public func remaining(at now: Date) -> Double { max(0, duration - elapsed(at: now)) }
    public func finished(at now: Date) -> Bool { countdown && remaining(at: now) <= 0 }
    public mutating func pause(at now: Date) { elapsed = elapsed(at: now); startedAt = nil }
    public mutating func start(at now: Date) { if startedAt == nil && !finished(at: now) { startedAt = now } }
    public mutating func reset() { elapsed = 0; startedAt = nil }
    public static func display(_ seconds: Double) -> String {
        let value = Int(min(359_999_999, max(0, seconds.isFinite ? seconds.rounded(.up) : 0)))
        return String(format: "%02d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
    }
}
