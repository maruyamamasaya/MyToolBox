import AppKit
import SwiftUI
@main struct RenderCompactUnixTimeConverter {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.unix.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/unix-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let zero = try ServerUtilities.epoch("0", unit: .seconds)
  let millis = try ServerUtilities.epoch("1000", unit: .milliseconds)
  let automatic = try ServerUtilities.epoch("1000000000000", unit: .automatic)
  let reverse = try ServerUtilities.date("1970-01-01 09:00:00", timeZone: TimeZone(identifier: "Asia/Tokyo")!)
  precondition(zero.timeIntervalSince1970 == 0 && millis.timeIntervalSince1970 == 1 && automatic.timeIntervalSince1970 == 1e9 && reverse == zero)
  let cases: [(String, Bool, String, ServerUtilities.EpochUnit, String)] = [("zero", false, "0", .automatic, "Asia/Tokyo"), ("milliseconds", false, "1000", .milliseconds, "UTC"), ("negative", false, "-1", .seconds, "local"), ("reverse", true, "0", .automatic, "Asia/Tokyo"), ("invalid", false, "invalid", .automatic, "Asia/Tokyo")]
  for theme in VisualTheme.allCases {
   for (name, reverse, input, unit, zone) in cases {
    for expanded in [false, true] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "Unix時刻変換") {
      UnixTimeConverterView(initiallyExpanded: expanded, initiallyReverse: reverse, initialInput: input, initialUnit: unit, initialZone: zone)
     }.defaultAppStorage(defaults))
     let size = NSSize(width: expanded ? 1100 : 420, height: (expanded ? 850 : 600) + (theme == .windows98 ? 30 : 0))
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
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 600), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 420, height: 600); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS native size roundtrip / actual zero, milliseconds, automatic unit and reverse conversions")
 }
}
