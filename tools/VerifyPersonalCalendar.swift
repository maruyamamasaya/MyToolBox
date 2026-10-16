import SwiftUI

@main struct VerifyPersonalCalendar {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let suite = "local.MyToolBox.CalendarProbe." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = PersonalCalendarModel(defaults: defaults)
        var birthday = PersonalCountdown(); birthday.title = "40歳まで"
        birthday.date = BusinessDays.calendar.date(byAdding: .day, value: 123, to: Date())!
        guard model.save(birthday) else { throw ToolFailure.message(model.error) }
        var hours = PersonalCountdown(); hours.title = "1万時間まで"; hours.kind = .hours; hours.completedHours = 3200
        guard model.save(hours) else { throw ToolFailure.message(model.error) }
        birthday.title = "40歳の誕生日まで"
        guard model.save(birthday), PersonalCalendarModel(defaults: defaults).entries == model.entries else { throw ToolFailure.message("編集・復元失敗") }
        print("PASS: add / edit / reopen two goals")
        for theme in VisualTheme.allCases {
            let size = NSSize(width: 820, height: 1100)
            let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "マイカレンダー") { PersonalCalendarView(model: model) })
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
            window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
            window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(450)); host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw ToolFailure.message("描画失敗") }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let folder = URL(fileURLWithPath: "build/personal-calendar-preview")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + ".png"))
            print("PASS: rendered " + theme.rawValue)
        }
        model.delete(birthday.id)
        guard PersonalCalendarModel(defaults: defaults).entries == [hours] else { throw ToolFailure.message("削除失敗") }
        print("PASS: delete / reopen")
    }
}
