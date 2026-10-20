import SwiftUI

@main struct VerifySecurity {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let store = MonitorStore()
        store.suspend() // Keep other monitoring/logging inactive in this probe.
        guard store.securityChecking, store.securityReadings.allSatisfy({ $0.state == .checking }) else { fatalError("startup") }
        store.refreshSecurity(); store.refreshSecurityIfNeeded()
        while store.securityChecking { try await Task.sleep(for: .milliseconds(30)) }
        let first = store.securityReadings.compactMap(\.checkedAt)
        guard first.count == 3 else { fatalError("completion") }
        for value in store.securityReadings { print("\(value.item.title): \(value.state.rawValue) \(value.reason)") }
        store.refreshSecurity()
        guard store.securityChecking, store.securityReadings.allSatisfy({ $0.state == .checking }) else { fatalError("refresh") }
        while store.securityChecking { try await Task.sleep(for: .milliseconds(30)) }
        guard zip(first, store.securityReadings.compactMap(\.checkedAt)).allSatisfy({ $0 < $1 }) else { fatalError("dates") }
        for theme in VisualTheme.allCases {
            let host = NSHostingView(rootView: ThemeRoot(override: theme) { Dashboard(store: store) })
            let size = Dashboard.preferredSize
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
            store.selected = "security"
            window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(150)); host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let folder = URL(fileURLWithPath: "build/security-preview")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + ".png"))
        }
        print("PASS: startup, checking, duplicate requests, refresh dates, real results, three themes")
    }
}
