import AppKit
import SwiftUI
@main struct RenderCompactDNSRecordBuilder {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.dns.builder.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/dns-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let cases = [("A", "192.0.2.1"), ("AAAA", "2001:db8::1"), ("CNAME", "example.com"), ("MX", "mail.example.com"), ("TXT", "v=spf1 include:example.com ~all")]
  let records = try cases.map { try NetworkBuilders.record(type: $0.0, host: "@", ttl: "3600", value: $0.1, priority: "10") }
  precondition(records[2].hasSuffix("example.com.") && records[3].hasSuffix("10 mail.example.com."))
  for theme in VisualTheme.allCases {
   for (type, value) in cases {
    for expanded in [false, true] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "DNSレコード作成") {
      DNSRecordBuilderView(initiallyExpanded: expanded, initialType: type, initialValue: value, initialRecords: records)
     }.defaultAppStorage(defaults))
     let size = NSSize(width: expanded ? 1100 : 400, height: (expanded ? 850 : 560) + (theme == .windows98 ? 30 : 0))
     let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
     window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
     window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
     window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(150)); host.layoutSubtreeIfNeeded()
     guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
     host.cacheDisplay(in: host.bounds, to: rep)
     try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(theme.rawValue)-\(type)-\(expanded ? "expanded" : "compact").png"))
     precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height)
     print("PASS \(theme.rawValue) \(type) expanded=\(expanded)")
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
  print("PASS native size roundtrip / actual DNS zone formatting, no network")
 }
}
