import SwiftUI
import Carbon

@MainActor private final class NoGlobalRegistration: ToolShortcutRegistration {
    func unregister() {}
    func register(keyCode: UInt32, signature: OSType, onPress: @escaping () -> Void) -> OSStatus {
        preconditionFailure("background calendar probe must not register global keys")
    }
}

@main struct VerifyPersonalCalendar {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
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
        let start = hours.date
        guard model.updateCompletedHours(hours.id, text: "3202.5") else { throw ToolFailure.message("累計更新失敗") }
        hours = model.entries.first { $0.id == hours.id }!
        guard hours.date == start, hours.completedHours == 3202.5,
              PersonalCalendarModel(defaults: defaults).entries == model.entries else { throw ToolFailure.message("累計更新・保存失敗") }
        let saved = model.entries
        for invalid in ["", "abc", "-1", "nan", "inf"] {
            guard !model.updateCompletedHours(hours.id, text: invalid), model.entries == saved else { throw ToolFailure.message("不正入力で変更") }
        }
        guard model.updateCompletedHours(hours.id, text: "3202.5"), model.entries == saved else { throw ToolFailure.message("同じ累計でデータが変更") }
        print("PASS: daily progress / invalid input / unchanged value / persistence")
        guard ToolID.personalCalendar.category == .calendar, ToolID.personalCountdown.category == .calendar else { throw ToolFailure.message("分離ツール登録失敗") }
        let shortcut = ToolShortcutModel(defaults: defaults, registration: NoGlobalRegistration())
        guard !shortcut.enabled, shortcut.key == "K" else { throw ToolFailure.message("ショートカット初期値失敗") }
        shortcut.setKey("J")
        guard ToolShortcutModel(defaults: defaults, registration: NoGlobalRegistration()).key == "J" else { throw ToolFailure.message("キー保存失敗") }
        shortcut.setKey("invalid")
        guard shortcut.key == "J" else { throw ToolFailure.message("不正キーを保存") }
        let holidayURL = URL(fileURLWithPath: "Resources/JapaneseHolidays.json")
        let holidaysModel = CalendarWorkspaceModel(holidayURL: holidayURL)
        guard holidaysModel.holidayNotice == nil,
              holidaysModel.holidays["2027-01-01"] != nil else { throw ToolFailure.message("祝日読込失敗") }
        for theme in VisualTheme.allCases {
            for countdown in [false, true] {
                let size = NSSize(width: countdown ? 980 : 1080, height: countdown ? 700 : 900)
                let root = ThemeRoot(override: theme, windowTitle: countdown ? "カウントダウン" : "マイカレンダー") {
                    if countdown { PersonalCountdownView(model: model) } else { PersonalCalendarView(holidays: holidaysModel, shortcut: shortcut) }
                }
                let host = NSHostingView(rootView: root.defaultAppStorage(defaults))
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
                window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
                window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(450)); host.layoutSubtreeIfNeeded()
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw ToolFailure.message("描画失敗") }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let folder = URL(fileURLWithPath: "build/personal-calendar-preview")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent((countdown ? "countdown-" : "calendar-") + theme.rawValue + ".png"))
                print("PASS: rendered " + (countdown ? "countdown " : "calendar ") + theme.rawValue)
            }
        }
        let holidays = try BusinessDays(data: Data(contentsOf: URL(fileURLWithPath: "Resources/JapaneseHolidays.json"))).holidays
        let date = BusinessDays.calendar.date(from: DateComponents(year: 2027, month: 1, day: 19))!
        for theme in VisualTheme.allCases {
            let size = NSSize(width: 1080, height: 850)
            let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "拡大カレンダー") {
                ExpandedCalendarView(month: .constant(date), selected: .constant(date), holidays: holidays)
            }.defaultAppStorage(defaults))
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
            window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
            window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(450)); host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw ToolFailure.message("拡大版描画失敗") }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "build/personal-calendar-preview/expanded-" + theme.rawValue + ".png"))
            print("PASS: rendered expanded calendar " + theme.rawValue)
        }
        model.delete(birthday.id)
        guard PersonalCalendarModel(defaults: defaults).entries == [hours] else { throw ToolFailure.message("削除失敗") }
        print("PASS: delete / reopen")
        let corrupt = Data("invalid countdown archive".utf8)
        defaults.set(corrupt, forKey: PersonalCountdownStore.key)
        let damaged = PersonalCalendarModel(defaults: defaults)
        guard damaged.loadFailed, !damaged.save(hours),
              defaults.data(forKey: PersonalCountdownStore.key) == corrupt else { throw ToolFailure.message("破損データを上書き") }
        print("PASS: corrupted shared-domain data preserved / writes blocked")
    }
}
