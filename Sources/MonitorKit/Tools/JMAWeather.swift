import Foundation
import CoreFoundation


public struct JMAWeatherRegion: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let office: String
    public let forecastArea: String
    public let station: String
    public let stationName: String
    public let latitude: Double
    public let longitude: Double
    public var radarURL: URL {
        URL(string: "https://www.jma.go.jp/bosai/nowc/#lat:\(latitude)/lon:\(longitude)/zoom:10")!
    }
    public static let regions: [Self] = [
        .init(id: "shinagawa", name: "東京都品川区", office: "130000", forecastArea: "130010", station: "44132", stationName: "東京", latitude: 35.6092, longitude: 139.7302),
        .init(id: "yokohama", name: "横浜市", office: "140000", forecastArea: "140010", station: "46106", stationName: "横浜", latitude: 35.4437, longitude: 139.6380),
        .init(id: "nagoya", name: "名古屋市", office: "230000", forecastArea: "230010", station: "51106", stationName: "名古屋", latitude: 35.1815, longitude: 136.9066),
        .init(id: "osaka", name: "大阪市", office: "270000", forecastArea: "270000", station: "62078", stationName: "大阪", latitude: 34.6937, longitude: 135.5023),
        .init(id: "sapporo", name: "札幌市", office: "016000", forecastArea: "016010", station: "14163", stationName: "札幌", latitude: 43.0618, longitude: 141.3545),
        .init(id: "fukuoka", name: "福岡市", office: "400000", forecastArea: "400010", station: "82182", stationName: "福岡", latitude: 33.5902, longitude: 130.4017)
    ]
    public static func resolve(_ id: String) -> Self { regions.first { $0.id == id } ?? regions[0] }
}

public enum JMAWeatherError: LocalizedError {
    case invalidData, http(Int), oversized
    public var errorDescription: String? {
        switch self {
        case .invalidData: return "気象庁のデータ形式または対象地域を確認できません。"
        case .http(let status): return "気象庁のデータを取得できません（HTTP \(status)）。"
        case .oversized: return "取得データが上限を超えました。"
        }
    }
}

public struct JMAObservation: Equatable, Sendable {
    public let date: Date
    public let temperature: Double?
    public let humidity: Double?
    public static func parse(_ data: Data, station: String, date: Date) throws -> Self {
        guard let map = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = map[station] as? [String: Any] else { throw JMAWeatherError.invalidData }
        func measurement(_ key: String, range: ClosedRange<Double>) -> Double? {
            guard let pair = values[key] as? [Any], pair.count == 2,
                  let quality = pair[1] as? NSNumber, CFGetTypeID(quality) != CFBooleanGetTypeID(), quality.doubleValue == 0,
                  let value = pair[0] as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
                  value.doubleValue.isFinite, range.contains(value.doubleValue) else { return nil }
            return value.doubleValue
        }
        return Self(date: date, temperature: measurement("temp", range: -100...70), humidity: measurement("humidity", range: 0...100))
    }
    public var isStale: Bool { Date().timeIntervalSince(date) >= 30 * 60 }
}

public struct JMAForecast: Equatable, Sendable {
    public let reportDate: Date
    public let targetDate: Date
    public let areaName: String
    public let text: String
    public let precipitation: [JMAPrecipitationPeriod]
    public func upcomingPrecipitation(now: Date = Date()) -> [JMAPrecipitationPeriod] {
        Array(precipitation.filter { $0.end > now }.sorted { $0.start < $1.start }.prefix(6))
    }
    public static func parse(_ data: Data, area: String, now: Date = Date()) throws -> Self {
        struct Report: Decodable {
            let reportDatetime: String
            let timeSeries: [Series]
        }
        struct Series: Decodable { let timeDefines: [String]; let areas: [Area] }
        struct Area: Decodable { let area: Place; let weathers: [String]?; let pops: [String]? }
        struct Place: Decodable { let code: String; let name: String }
        let reports = try JSONDecoder().decode([Report].self, from: data)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        for report in reports {
            for series in report.timeSeries {
                guard let item = series.areas.first(where: { $0.area.code == area }), let texts = item.weathers,
                      let index = series.timeDefines.firstIndex(where: { time in
                          date(time).map { calendar.isDate($0, inSameDayAs: now) } ?? false
                      }), texts.indices.contains(index), !texts[index].isEmpty,
                      let target = date(series.timeDefines[index]), let published = date(report.reportDatetime) else { continue }
                var precipitation: [JMAPrecipitationPeriod] = []
                for probabilitySeries in report.timeSeries {
                    guard let probabilityArea = probabilitySeries.areas.first(where: { $0.area.code == area }),
                          let probabilities = probabilityArea.pops else { continue }
                    for (slot, timestamp) in probabilitySeries.timeDefines.enumerated() {
                        guard let start = date(timestamp) else { continue }
                        let raw = probabilities.indices.contains(slot) ? probabilities[slot] : ""
                        let parsed = Int(raw)
                        let percent = parsed.flatMap { (0...100).contains($0) ? $0 : nil }
                        precipitation.append(JMAPrecipitationPeriod(start: start, end: start.addingTimeInterval(6 * 3600), percent: percent))
                    }
                    break
                }
                return Self(reportDate: published, targetDate: target, areaName: item.area.name,
                            text: texts[index].replacingOccurrences(of: "　", with: " "), precipitation: precipitation)
            }
        }
        throw JMAWeatherError.invalidData
    }
    public static func date(_ text: String) -> Date? { ISO8601DateFormatter().date(from: text.trimmingCharacters(in: .whitespacesAndNewlines)) }
}

public enum JMAWeatherService {
    public static func fetch(_ url: URL) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15; configuration.timeoutIntervalForResource = 25
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        guard let response = response as? HTTPURLResponse else { throw JMAWeatherError.invalidData }
        guard response.statusCode == 200 else { throw JMAWeatherError.http(response.statusCode) }
        guard data.count <= 8 * 1024 * 1024 else { throw JMAWeatherError.oversized }
        return data
    }
    public static func observation(_ region: JMAWeatherRegion) async throws -> JMAObservation {
        let timeData = try await fetch(URL(string: "https://www.jma.go.jp/bosai/amedas/data/latest_time.txt")!)
        guard let text = String(data: timeData, encoding: .utf8), let date = JMAForecast.date(text) else { throw JMAWeatherError.invalidData }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo"); formatter.dateFormat = "yyyyMMddHHmmss"
        let data = try await fetch(URL(string: "https://www.jma.go.jp/bosai/amedas/data/map/\(formatter.string(from: date)).json")!)
        return try JMAObservation.parse(data, station: region.station, date: date)
    }
    public static func forecast(_ region: JMAWeatherRegion) async throws -> JMAForecast {
        let data = try await fetch(URL(string: "https://www.jma.go.jp/bosai/forecast/data/forecast/\(region.office).json")!)
        return try JMAForecast.parse(data, area: region.forecastArea)
    }
}

/// Values older than 30 minutes must not look like current observations in the menu.
public enum JMAWeatherMenu {
    public static func title(observation: JMAObservation?, busy: Bool, now: Date = Date()) -> String {
        guard let observation else { return busy ? "…°C …%" : "—°C —%" }
        guard now.timeIntervalSince(observation.date) < 30 * 60 else { return "—°C —%" }
        let temperature = observation.temperature.map { String(format: "%.1f°C", $0) } ?? "—°C"
        let humidity = observation.humidity.map { String(format: "%.0f%%", $0) } ?? "—%"
        return temperature + " " + humidity
    }
}

public enum JMAWeatherIcon: String, CaseIterable, Sendable {
    case sunny, cloudy, rainy, snowy, unknown
    public var symbol: String {
        switch self {
        case .sunny: return "sun.max"
        case .cloudy: return "cloud"
        case .rainy: return "cloud.rain"
        case .snowy: return "cloud.snow"
        case .unknown: return "questionmark.circle"
        }
    }
    public static func primaryForecast(_ text: String) -> Self {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("晴れ") { return .sunny }
        if text.hasPrefix("くもり") || text.hasPrefix("曇り") { return .cloudy }
        if text.hasPrefix("雨") || text.hasPrefix("暴風雨") { return .rainy }
        if text.hasPrefix("雪") || text.hasPrefix("風雪") || text.hasPrefix("暴風雪") { return .snowy }
        return .unknown
    }
}

extension JMAForecast {
    public func menuIcon(now: Date = Date()) -> JMAWeatherIcon {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        guard calendar.isDate(targetDate, inSameDayAs: now) else { return .unknown }
        return JMAWeatherIcon.primaryForecast(text)
    }
}


public struct JMAPrecipitationPeriod: Equatable, Identifiable, Sendable {
    public let start: Date
    public let end: Date
    public let percent: Int?
    public var id: Date { start }
    public var label: String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo"); formatter.dateFormat = "M/d HH"
        let beginning = formatter.string(from: start)
        formatter.dateFormat = "HH"
        let ending = formatter.string(from: end)
        return beginning + "–" + (ending == "00" ? "24" : ending) + "時"
    }
}
