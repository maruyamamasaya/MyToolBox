import SwiftUI

@MainActor final class PersonalCalendarModel: ObservableObject {
    @Published var entries: [PersonalCountdown] = []
    @Published var error = ""
    @Published var loadFailed = false
    private let defaults: UserDefaults
    init(defaults: UserDefaults = IndependentTools.defaults) {
        self.defaults = defaults
        do { entries = try PersonalCountdownStore.load(defaults: defaults) }
        catch { self.error = "保存した目標を読み込めません：" + error.localizedDescription; loadFailed = true }
    }
    func save(_ entry: PersonalCountdown) -> Bool {
        guard !loadFailed else { return false }
        do {
            try entry.validate()
            var updated = entries
            if let index = updated.firstIndex(where: { $0.id == entry.id }) { updated[index] = entry }
            else { updated.append(entry) }
            try PersonalCountdownStore.save(updated, defaults: defaults)
            entries = updated; error = ""; return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func updateCompletedHours(_ id: UUID, text: String) -> Bool {
        guard var entry = entries.first(where: { $0.id == id }), !loadFailed else { return false }
        guard let hours = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), hours.isFinite, hours >= 0 else {
            error = "累計時間は0以上の数値を入力してください"; return false
        }
        guard hours != entry.completedHours else { error = ""; return true }
        do {
            try entry.updateCompletedHours(hours)
            return save(entry)
        } catch { self.error = error.localizedDescription; return false }
    }
    func delete(_ id: UUID) {
        do {
            let updated = entries.filter { $0.id != id }
            try PersonalCountdownStore.save(updated, defaults: defaults)
            entries = updated; error = ""
        } catch { self.error = error.localizedDescription }
    }
}

struct PersonalCalendarView: View {
    @Environment(\.appTheme) private var theme
    @StateObject private var holidays: CalendarWorkspaceModel
    @ObservedObject private var shortcut: ToolShortcutModel
    @State private var selected = Date()
    @State private var month = Date()
    @State private var showsSettings = false
    private let calendar = BusinessDays.calendar
    init(holidays: CalendarWorkspaceModel? = nil, shortcut: ToolShortcutModel? = nil) {
        _holidays = StateObject(wrappedValue: holidays ?? CalendarWorkspaceModel())
        self.shortcut = shortcut ?? .calendar
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            VStack(spacing: 0) {
                ExpandedCalendarView(month: $month, selected: $selected, holidays: holidays.holidays,
                    settings: {
                        AnyView(Button { showsSettings.toggle() } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel("ショートカット設定")
                            .popover(isPresented: $showsSettings) { shortcutSettings.padding(16).frame(width: 300) })
                    })
                if let notice = holidays.holidayNotice { Text(notice).font(theme.font(10)).foregroundStyle(.secondary).padding(.bottom, 8) }
                if !shortcut.error.isEmpty { Text(shortcut.error).font(theme.font(11)).foregroundStyle(.red).padding(.bottom, 8) }
            }
        }
        .environment(\.calendar, calendar).environment(\.timeZone, calendar.timeZone)
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .onChange(of: month) { _, value in holidays.month = calendar.date(byAdding: .month, value: 3, to: value)! }
    }

    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("ショートカットで開く", isOn: Binding(get: { shortcut.enabled }, set: { shortcut.setEnabled($0) }))
            HStack {
                Text("⌃⌥⌘")
                Picker("キー", selection: Binding(get: { shortcut.key }, set: { shortcut.setKey($0) })) {
                    ForEach(ToolShortcutModel.keys, id: \.name) { item in Text(item.name).tag(item.name) }
                }
            }
            Text("MyToolBoxの起動中は、ほかのアプリからも開けます。").font(.caption).foregroundStyle(.secondary)
        }
    }

}

struct PersonalCountdownView: View {
    @Environment(\.appTheme) private var theme
    @StateObject private var model: PersonalCalendarModel
    init(model: PersonalCalendarModel? = nil) { _model = StateObject(wrappedValue: model ?? PersonalCalendarModel()) }
    @State private var draft: PersonalCountdown?
    @State private var deleting: PersonalCountdown?
    var body: some View {
        ToolPage("カウントダウン", subtitle: "大切な日や目標まで、あと何日。", symbol: "hourglass", tint: .mint) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            ToolSectionLabel(title: "カウントダウン", symbol: "hourglass")
                            Spacer()
                            Button("目標を追加") { var entry = PersonalCountdown(); entry.date = Date(); draft = entry }
                                .buttonStyle(ThemeButtonStyle(prominent: true)).disabled(model.loadFailed)
                        }
                        if !model.error.isEmpty { Text(model.error).foregroundStyle(.red).textSelection(.enabled) }
                        if model.entries.isEmpty && !model.loadFailed {
                            Text("「40歳まで」「1万時間まで」など、名前と目標を自分で設定できます。")
                                .font(theme.font(12)).foregroundStyle(.secondary).padding(.vertical, 12)
                        }
                        ForEach(model.entries) { entry in
                            countdownCard(entry, now: context.date)
                        }
                        ToolFootnote(text: "目標はこのMacに自動保存。日数は日本時間の暦日で計算し、今日は0日です。時間の目標は見積もりで、累計時間は自分で更新します。")
                    }.padding(24)
                }
            }
        }
        .frame(minWidth: 880, minHeight: 520)
        .environment(\.calendar, BusinessDays.calendar).environment(\.timeZone, BusinessDays.calendar.timeZone)
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .sheet(item: $draft) { entry in CountdownEditor(entry: entry) { model.save($0) } }
        .alert("目標を削除しますか？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("キャンセル", role: .cancel) { deleting = nil }
            Button("削除", role: .destructive) { if let deleting { model.delete(deleting.id) }; deleting = nil }
        } message: { Text(deleting?.title ?? "") }
    }
    private func countdownCard(_ entry: PersonalCountdown, now: Date) -> some View {
        let days = entry.remainingDays(now: now)
        return ToolCard {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title).font(theme.font(17, weight: .semibold)).textSelection(.enabled)
                    if entry.kind == .hours {
                        Text("開始日：" + BusinessDays.key(entry.date)).font(theme.font(14))
                        Text("1日あたり：\(entry.hoursPerDay.formatted())時間 · 目標：\(entry.targetHours.formatted())時間").font(theme.font(14))
                        CountdownProgressInput(entry: entry) { model.updateCompletedHours(entry.id, text: $0) }
                    }
                    if let date = entry.targetDate {
                        Text((entry.kind == .date ? "目標日：" + BusinessDays.key(date) : "終了予定日：" + BusinessDays.key(date)))
                            .font(theme.font(14)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("編集") { draft = entry }
                        Button("削除") { deleting = entry }
                    }
                }
                Spacer()
                Text(entry.kind == .hours && entry.completedHours >= entry.targetHours ? "目標達成" : days < 0 ? "\(-days)日経過" : days == 0 ? "当日" : "あと\(days)日")
                    .font(theme.font(26, weight: .bold, design: .rounded)).monospacedDigit()
            }
        }
    }
}

private struct CountdownProgressInput: View {
    let entry: PersonalCountdown
    var save: (String) -> Bool
    @State private var text: String
    init(entry: PersonalCountdown, save: @escaping (String) -> Bool) {
        self.entry = entry; self.save = save
        _text = State(initialValue: String(entry.completedHours))
    }
    var body: some View {
        HStack {
            Text("累計時間")
            TextField("累計時間", text: $text)
                .textFieldStyle(ThemeTextFieldStyle()).frame(width: 120)
                .accessibilityLabel(entry.title + "の累計時間")
                .onSubmit { commit() }
            Text("時間")
            Button("更新") { commit() }
                .disabled(Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) == entry.completedHours)
        }
        .onChange(of: entry.completedHours) { _, value in text = String(value) }
        .help("累計の合計時間を入力し、更新またはEnterで保存します。開始日は変わりません。")
    }
    private func commit() { _ = save(text) }
}

private struct CountdownEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var entry: PersonalCountdown
    @State private var error = ""
    var save: (PersonalCountdown) -> Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("カウントダウンの設定").font(.title2.bold())
            TextField("名前（例：40歳まで）", text: $entry.title).textFieldStyle(ThemeTextFieldStyle())
            ThemePicker("目標の種類", selection: $entry.kind, options: PersonalCountdown.Kind.allCases.map { ($0, $0.rawValue) })
            if entry.kind == .date {
                DatePicker("目標の日付", selection: $entry.date, displayedComponents: .date)
                Text("年齢の目標は、その年齢になる誕生日を指定してください。").font(.caption).foregroundStyle(.secondary)
            } else {
                numberField("目標時間", value: $entry.targetHours)
                if entry.kind == .hours {
                    DatePicker("開始日", selection: $entry.date, displayedComponents: .date)
                    numberField("累計時間", value: $entry.completedHours)
                    numberField("1日あたりの時間", value: $entry.hoursPerDay)
                    Text("開始日から残り時間で終了予定日を計算します。累計を更新しても、計算の基準は開始日のままです。").font(.caption).foregroundStyle(.secondary)
                } else {
                    DatePicker("開始日", selection: $entry.date, displayedComponents: .date)
                    Text("開始日から指定した時間が経過する日まで数えます。").font(.caption).foregroundStyle(.secondary)
                }
            }
            if entry.kind != .date, let end = entry.targetDate {
                Text("終了予定日：" + BusinessDays.key(end)).font(.headline)
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("キャンセル") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") {
                    do { try entry.validate(); if save(entry) { dismiss() } else { error = "保存できませんでした。元の画面のエラーを確認してください。" } }
                    catch { self.error = error.localizedDescription }
                }.keyboardShortcut(.defaultAction)
            }
        }.padding(26).frame(width: 560)
    }
    private func numberField(_ title: String, value: Binding<Double>) -> some View {
        HStack { Text(title); Spacer(); TextField(title, value: value, format: .number).textFieldStyle(ThemeTextFieldStyle()).frame(width: 170) }
    }
}
