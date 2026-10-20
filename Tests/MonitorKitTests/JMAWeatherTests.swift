import XCTest
@testable import MonitorKit

final class JMAWeatherTests: XCTestCase {
    func testObservationQualityAndMissingValues() throws {
        let date = Date(timeIntervalSince1970: 0)
        let data = Data(#"{"44132":{"temp":[0,0],"humidity":[null,5]}}"#.utf8)
        let result = try JMAObservation.parse(data, station: "44132", date: date)
        XCTAssertEqual(result.temperature, 0); XCTAssertNil(result.humidity)
        for payload in [#"{"temp":[28,1],"humidity":[101,0]}"#, #"{"temp":[true,0],"humidity":[50,true]}"#] {
            let result = try JMAObservation.parse(Data(("{\"44132\":" + payload + "}").utf8), station: "44132", date: date)
            XCTAssertNil(result.temperature); XCTAssertNil(result.humidity)
        }
        XCTAssertThrowsError(try JMAObservation.parse(data, station: "other", date: date))
    }
    func testForecastSelectsTodayInJapanAndCorrectArea() throws {
        let data = Data(#"[{"reportDatetime":"2026-10-20T17:00:00+09:00","timeSeries":[{"timeDefines":["2026-10-20T17:00:00+09:00","2026-10-21T00:00:00+09:00"],"areas":[{"area":{"code":"other","name":"他地域"},"weathers":["雪","雪"]},{"area":{"code":"130010","name":"東京地方"},"weathers":["晴れ","くもり　所により　雨"]}]}]}]"#.utf8)
        let now = JMAForecast.date("2026-10-20T16:00:00Z")!
        let forecast = try JMAForecast.parse(data, area: "130010", now: now)
        XCTAssertEqual(forecast.text, "くもり 所により 雨")
        XCTAssertEqual(forecast.areaName, "東京地方")
        XCTAssertThrowsError(try JMAForecast.parse(data, area: "130010", now: now.addingTimeInterval(86400)))
    }
    func testRegionDefaultsToShinagawa() {
        let region = JMAWeatherRegion.resolve("unknown")
        XCTAssertEqual(region.id, "shinagawa"); XCTAssertEqual(region.station, "44132")
        XCTAssertTrue(region.radarURL.absoluteString.contains("zoom:10"))
        XCTAssertEqual(Set(JMAWeatherRegion.regions.map(\.id)).count, JMAWeatherRegion.regions.count)
    }
    func testMenuFreshMissingAndExpiredObservations() throws {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let valid = try JMAObservation.parse(Data(#"{"s":{"temp":[0,0],"humidity":[70,0]}}"#.utf8), station: "s", date: date)
        XCTAssertEqual(JMAWeatherMenu.title(observation: valid, busy: false, now: date), "0.0°C 70%")
        XCTAssertEqual(JMAWeatherMenu.title(observation: valid, busy: false, now: date.addingTimeInterval(1799)), "0.0°C 70%")
        XCTAssertEqual(JMAWeatherMenu.title(observation: valid, busy: false, now: date.addingTimeInterval(1800)), "—°C —%")
        let partial = try JMAObservation.parse(Data(#"{"s":{"temp":[-2.5,0]}}"#.utf8), station: "s", date: date)
        XCTAssertEqual(JMAWeatherMenu.title(observation: partial, busy: false, now: date), "-2.5°C —%")
        XCTAssertEqual(JMAWeatherMenu.title(observation: nil, busy: true), "…°C …%")
        XCTAssertEqual(JMAWeatherMenu.title(observation: nil, busy: false), "—°C —%")
    }

    func testPrimaryForecastIconDoesNotTreatLocalRainAsDominant() {
        for text in ["晴れ", "晴れ 時々 くもり", " 晴れ のち 雨"] {
            XCTAssertEqual(JMAWeatherIcon.primaryForecast(text), .sunny)
        }
        XCTAssertEqual(JMAWeatherIcon.primaryForecast("くもり 所により 雨"), .cloudy)
        XCTAssertEqual(JMAWeatherIcon.primaryForecast("雨 のち 晴れ"), .rainy)
        XCTAssertEqual(JMAWeatherIcon.primaryForecast("雪 時々 止む"), .snowy)
        XCTAssertEqual(JMAWeatherIcon.primaryForecast("暴風雪"), .snowy)
        XCTAssertEqual(JMAWeatherIcon.primaryForecast("不明"), .unknown)
        XCTAssertEqual(JMAWeatherIcon.primaryForecast(""), .unknown)
    }
    func testForecastIconExpiresAtJapanDateBoundary() throws {
        let data = Data(#"[{"reportDatetime":"2026-10-20T17:00:00+09:00","timeSeries":[{"timeDefines":["2026-10-20T17:00:00+09:00"],"areas":[{"area":{"code":"130010","name":"東京地方"},"weathers":["くもり 所により 雨"]}]}]}]"#.utf8)
        let now = JMAForecast.date("2026-10-20T23:59:00+09:00")!
        let forecast = try JMAForecast.parse(data, area: "130010", now: now)
        XCTAssertEqual(forecast.menuIcon(now: now), .cloudy)
        XCTAssertEqual(forecast.menuIcon(now: now.addingTimeInterval(60)), .unknown)
    }

    func testPrecipitationTimeRangesMissingAndZero() throws {
        let data = Data(#"[{"reportDatetime":"2026-10-20T11:00:00+09:00","timeSeries":[{"timeDefines":["2026-10-20T11:00:00+09:00"],"areas":[{"area":{"code":"130010","name":"東京地方"},"weathers":["くもり"]}]},{"timeDefines":["2026-10-20T06:00:00+09:00","2026-10-20T12:00:00+09:00","2026-10-20T18:00:00+09:00","2026-10-21T00:00:00+09:00","2026-10-21T06:00:00+09:00"],"areas":[{"area":{"code":"other","name":"他地域"},"pops":["100","100","100","100","100"]},{"area":{"code":"130010","name":"東京地方"},"pops":["90","0","--","101"]}]}]}]"#.utf8)
        let now = JMAForecast.date("2026-10-20T14:00:00+09:00")!
        let forecast = try JMAForecast.parse(data, area: "130010", now: now)
        let periods = forecast.upcomingPrecipitation(now: now)
        XCTAssertEqual(periods.count, 4)
        XCTAssertEqual(periods[0].percent, 0)
        XCTAssertNil(periods[1].percent); XCTAssertNil(periods[2].percent); XCTAssertNil(periods[3].percent)
        XCTAssertEqual(periods[1].label, "10/20 18–24時")
        XCTAssertEqual(periods[2].label, "10/21 00–06時")
        XCTAssertEqual(forecast.upcomingPrecipitation(now: periods[0].end).first?.start, periods[1].start)
        XCTAssertTrue(forecast.upcomingPrecipitation(now: periods.last!.end).isEmpty)
    }

}
