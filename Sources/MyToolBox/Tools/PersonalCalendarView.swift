import SwiftUI

@MainActor final class PersonalCalendarModel: ObservableObject {
    @Published var entries: [PersonalCountdown] = []
    @Published var error = ""
    @Published var loadFailed = false
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
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
    @StateObject private var model: PersonalCalendarModel
    init(model: PersonalCalendarModel? = nil) { _model = StateObject(wrappedValue: model ?? PersonalCalendarModel()) }
    @StateObject private var holidays = CalendarWorkspaceModel()
    @State private var selected = Date()
    @State private var month = Date()
    @State private var draft: PersonalCountdown?
    @State private var deleting: PersonalCountdown?
    var body: some View {
        ToolPage("マイカレンダー", subtitle: "日付を眺める。大切な日や目標まで、あと何日。", symbol: "calendar", tint: .mint) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ToolCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(context.date.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: Locale(identifier: "ja_JP"), calendar: BusinessDays.calendar, timeZone: BusinessDays.calendar.timeZone))).font(theme.font(16, weight: .semibold))
                                    Spacer()
                                    Button("今日") { selected = context.date; month = context.date }
                                }
                                ToolCalendar(selection: $selected, holidays: holidays.holidays, visibleMonth: $month,
                                             showsAdjacentDays: true, showsHolidayNames: true, showsCellBorders: true, rowHeight: 48)
                                Text("選択日：" + BusinessDays.key(selected)).font(theme.font(12))
                                if let name = holidays.holidays[BusinessDays.key(selected)] { Text(name).foregroundStyle(.red) }
                                if let notice = holidays.holidayNotice { Text(notice).font(theme.font(11)).foregroundStyle(.secondary) }
                            }
                        }
                        HStack {
                            ToolSectionLabel(title: "カウントダウン", symbol: "hourglass")
                            Spacer()
                            Button("目標を追加") { var entry = PersonalCountdown(); entry.date = selected; draft = entry }
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
        .frame(minWidth: 700, minHeight: 760)
        .environment(\.calendar, BusinessDays.calendar).environment(\.timeZone, BusinessDays.calendar.timeZone)
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .onChange(of: month) { _, value in holidays.month = value }
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
                    if let date = entry.targetDate { Text("目標日：" + BusinessDays.key(date)).font(theme.font(12)).foregroundStyle(.secondary) }
                    else { Text("\(entry.completedHours.formatted()) / \(entry.targetHours.formatted())時間 · 1日\(entry.hoursPerDay.formatted())時間の見積もり").font(theme.font(12)).foregroundStyle(.secondary) }
                    HStack {
                        Button("編集") { draft = entry }
                        Button("削除") { deleting = entry }
                    }
                }
                Spacer()
                Text(days < 0 ? "\(-days)日経過" : days == 0 ? (entry.kind == .hours ? "目標達成" : "当日") : "あと\(days)日")
                    .font(theme.font(26, weight: .bold, design: .rounded)).monospacedDigit()
            }
        }
    }
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
                    numberField("現在の累計時間", value: $entry.completedHours)
                    numberField("1日あたりの時間", value: $entry.hoursPerDay)
                    Text("残り時間 ÷ 1日あたりの時間を切り上げた見積もり。累計は自動加算しません。").font(.caption).foregroundStyle(.secondary)
                } else {
                    DatePicker("開始日時", selection: $entry.date)
                    Text("開始日時から指定した時間が経過する日まで数えます。").font(.caption).foregroundStyle(.secondary)
                }
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
        }.padding(26).frame(width: 480)
    }
    private func numberField(_ title: String, value: Binding<Double>) -> some View {
        HStack { Text(title); Spacer(); TextField(title, value: value, format: .number).textFieldStyle(ThemeTextFieldStyle()).frame(width: 170) }
    }
}
