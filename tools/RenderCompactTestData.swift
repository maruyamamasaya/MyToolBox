import AppKit
import SwiftUI
@main struct RenderCompactTestData {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.testdata.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/test-data-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["文章", "文字列", "CSV", "UUID", "未生成"] {
    let model = GeneratorModel()
    let mode = state == "未生成" ? "文字列" : state
    if state != "未生成" {
     model.generate {
      switch mode {
      case "文章": return try TestDataGenerator.sentences(count: 3, length: 1, language: "ja")
      case "CSV": return try TestDataGenerator.csv(columns: Array(TestDataGenerator.defaultColumns.prefix(5)), count: 5)
      case "UUID": return try TestDataGenerator.uuids(count: 5).joined(separator: "\n")
      default: return try TestDataGenerator.text(kind: .ja, length: 20, count: 5, separator: "\n")
      }
     }
     while model.busy { try await Task.sleep(for: .milliseconds(10)) }
    }
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "テストデータ生成") {
     TestDataGeneratorView(model: model, initialMode: mode)
    }.defaultAppStorage(defaults))
    let size = NSSize(width: 340, height: theme == .windows98 ? 370 : 340)
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
    window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
    host.cacheDisplay(in: host.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + "-" + state + ".png"))
    print("PASS \(theme.rawValue) \(state) fitting \(host.fittingSize)")
    model.clear()
   }
  }
 }
}
