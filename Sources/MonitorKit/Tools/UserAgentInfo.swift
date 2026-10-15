import Foundation

/// UA claims only; versions and device type are not verified hardware information.
public struct UserAgentInfo: Equatable {
    public let browser: String
    public let os: String
    public let device: String
    public init(_ ua: String) {
        func capture(_ pattern: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: ua, range: NSRange(ua.startIndex..., in: ua)),
                  let range = Range(match.range(at: 1), in: ua) else { return nil }
            return String(ua[range])
        }
        let rules = [("(?:EdgiOS|EdgA|Edg)/([\\d.]+)", "Microsoft Edge"),
                     ("(?:OPiOS|OPR)/([\\d.]+)", "Opera"),
                     ("SamsungBrowser/([\\d.]+)", "Samsung Internet"),
                     ("(?:CriOS|Chrome)/([\\d.]+)", "Google Chrome"),
                     ("(?:FxiOS|Firefox)/([\\d.]+)", "Mozilla Firefox"),
                     ("Version/([\\d.]+).*Safari/", "Safari")]
        browser = rules.compactMap { pattern, name in capture(pattern).map { name + " " + $0 } }.first
            ?? (ua.contains("AppleWebKit/") ? "WebKit（ブラウザ名不明）" : "不明")
        if let v = capture("Windows NT ([\\d.]+)") {
            os = ["10.0": "Windows 10 / 11", "6.3": "Windows 8.1", "6.2": "Windows 8", "6.1": "Windows 7"][v] ?? "Windows NT \(v)"
        } else if let v = capture("(?:iPhone )?OS ([\\d_]+)") { os = "iOS " + v.replacingOccurrences(of: "_", with: ".")
        } else if let v = capture("Android ([\\d.]+)") { os = "Android " + v
        } else if ua.contains("CrOS") { os = "ChromeOS"
        } else if let v = capture("Mac OS X ([\\d_]+)") { os = "macOS " + v.replacingOccurrences(of: "_", with: ".")
        } else if ua.contains("Linux") { os = "Linux"
        } else { os = "不明" }
        if ua.range(of: "iPad|Tablet|PlayBook|Silk", options: [.regularExpression, .caseInsensitive]) != nil || (ua.contains("Android") && !ua.contains("Mobile")) { device = "Tablet"
        } else if ua.range(of: "Mobi|iPhone|iPod|Android", options: [.regularExpression, .caseInsensitive]) != nil { device = "Mobile"
        } else if ua.contains("Macintosh") || ua.contains("Windows") || ua.contains("X11") || ua.contains("CrOS") { device = "Desktop"
        } else { device = "不明" }
    }
}
