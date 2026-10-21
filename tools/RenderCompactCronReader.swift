import AppKit
import SwiftUI
@main struct RenderCompactCronReader {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.cron.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/cron-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let zone = TimeZone(identifier: "Asia/Tokyo")!
  let start = try ServerUtilities.date("2026-10-21 08:59:00", timeZone: zone)
  let cron = try ServerUtilities.cron("0 9 * * 1-5")
  let dates = cron.next(after: start, timeZone: zone)
  precondition(dates.count == 5 && ServerUtilities.dateText(dates[0], timeZone: zone) == "2026-10-21 09:00:00 +09:00")
  let output: Result<[(String, String)], Error> = .success([("Cron式", cron.fields.joined(separator: " ")), ("条件", cron.descriptions.joined(separator: "\n")), ("次回予定（Asia/Tokyo）", dates.map { ServerUtilities.dateText($0, timeZone: zone) }.joined(separator: "\n"))])
  let cases = [("reader", 0, "毎日", "0 9 * * 1-5"), ("weekly", 1, "毎週", "0 9 * * 1-5"), ("monthly", 1, "毎月", "0 9 * * 1-5"), ("invalid", 0, "毎日", "60 * * * *")]
  for theme in VisualTheme.allCases {
   for (name, tab, pattern, input) in cases {
    for expanded in [false, true] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "Cron解読・作成") {
      CronReaderView(initiallyExpanded: expanded, initialTab: tab, initialInput: input, initialPattern: pattern, initialOutput: name == "reader" ? output : nil)
     }.defaultAppStorage(defaults))
     let size = NSSize(width: expanded ? 1100 : 400, height: (expanded ? 850 : 560) + (theme == .windows98 ? 30 : 0))
     let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
     window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
     window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
     window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(150)); host.layoutSubtreeIfNeeded()
     guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
     host.cacheDisplay(in: host.bounds, to: rep)
     try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(theme.rawValue)-\(name)-\(expanded ? "expanded" : "compact").png"))
     precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height)
     print("PASS \(theme.rawValue) \(name) expanded=\(expanded)")
    }
   }
  }
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 560), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 400, height: 560); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS native size roundtrip / actual next five dates, no scheduler changes")
 }
}
