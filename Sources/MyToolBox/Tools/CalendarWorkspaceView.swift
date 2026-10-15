import SwiftUI

@MainActor final class CalendarWorkspaceModel: ObservableObject {
    @Published var start = Date()
    @Published var end = Date()
    @Published var customDate = Date()
    @Published var customName = ""
    @Published var custom: [String: String] = [:]
    @Published var format = 0
    @Published var status = ""
    @Published var candidates = ScheduleCandidates()
    @Published var month = Date()
    @Published var candidateStatus = ""
    @Published var defaultHourSelection = ScheduleCandidates.HourSelection()
    @Published var hourSelections: [Date: ScheduleCandidates.HourSelection] = [:]
    var hasPendingHours: Bool { defaultHourSelection.anchor != nil || candidates.dates.contains { hourSelections[$0]?.anchor != nil } }
    func chooseCandidate(_ date: Date) {
        guard defaultHourSelection.anchor == nil else { return }
        candidates.choose(date)
        let day = BusinessDays.calendar.startOfDay(for: date)
        if !candidates.selected.contains(day) { hourSelections[day] = nil }
        candidateStatus = ""
    }
    func clearCandidates() {
        candidates.clear(); hourSelections.removeAll(); defaultHourSelection.cancel()
    }
    func removeCandidate(_ date: Date) { candidates.remove(date); hourSelections[date] = nil }

    let source: Result<BusinessDays, Error>
    init(holidayURL: URL? = Bundle.main.url(forResource: "JapaneseHolidays", withExtension: "json")) {
        source = Result {
            guard let holidayURL else { throw ToolFailure.message("祝日データが見つかりません") }
            return try BusinessDays(data: Data(contentsOf: holidayURL))
        }
    }
    var holidays: [String: String] { ((try? source.get().holidays) ?? [:]).merging(custom) { _, custom in custom } }
    var holidayNotice: String? {
        if case .failure(let error) = source { return error.localizedDescription + "。公式祝日の色分けは利用できません。" }
        if !(1955...2027).contains(BusinessDays.calendar.component(.year, from: month)) { return "公式祝日データは1955〜2027年に対応しています。この月の公式祝日は表示できません。" }
        return nil
    }
}
struct CalendarWorkspaceView: View {
    @Environment(\.appTheme) private var theme
    @StateObject private var model: CalendarWorkspaceModel
    @State private var mode = "日程候補"
    init(model: CalendarWorkspaceModel? = nil) { _model = StateObject(wrappedValue: model ?? CalendarWorkspaceModel()) }
    var body: some View {
        ToolPage("カレンダー", subtitle: "候補日をまとめる。営業日を数える。", symbol: "calendar", tint: .mint) {
            VStack(spacing: 0) {
                ThemePicker("カレンダーのモード", selection: $mode, options: ["日程候補", "営業日計算"].map { ($0, $0) }, tabs: true)
                    .frame(width: 360).padding(.top, 16).padding(.bottom, 4)
                if mode == "日程候補" { ScheduleCandidatesView(model: model) }
                else { BusinessDaysView(model: model, embedded: true) }
            }
        }.environment(\.calendar, BusinessDays.calendar).environment(\.timeZone, BusinessDays.calendar.timeZone)
            .frame(minWidth: 900, minHeight: 820)
    }
}
struct CalendarHolidayEditor: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var model: CalendarWorkspaceModel
    var body: some View {
        ToolCard {
            VStack(alignment: .leading, spacing: 10) {
                ToolSectionLabel(title: "独自の休日（両モードで共有）", symbol: "calendar.badge.exclamationmark")
                HStack {
                    DatePicker("休日の日付", selection: $model.customDate, displayedComponents: .date).labelsHidden()
                    TextField("会社の休業日など", text: $model.customName).textFieldStyle(ThemeTextFieldStyle())
                    Button("追加") {
                        model.custom[BusinessDays.key(model.customDate)] = String(model.customName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
                        model.customName = ""
                    }.disabled(model.customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(model.custom.keys.sorted(), id: \.self) { key in
                    HStack {
                        Text(key).monospacedDigit(); Text(model.custom[key] ?? ""); Spacer()
                        Button("削除") { model.custom[key] = nil }.accessibilityLabel(key + "の独自休日を削除")
                    }.font(theme.font(11))
                }
                Text("このウィンドウを閉じるまで有効です。候補日から休日を自動で除外することはありません。").font(theme.font(11)).foregroundStyle(.secondary)
            }
        }
    }
}
struct ScheduleCandidatesView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var model: CalendarWorkspaceModel
    private var output: String { model.hasPendingHours ? "" : (try? model.candidates.formatted()) ?? "" }
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 18) {
                    ToolCard {
                        VStack(alignment: .leading, spacing: 14) {
                            ToolSectionLabel(title: "候補日を選択", symbol: "calendar.badge.plus")
                            ToolCalendar(selection: .constant(model.month), holidays: model.holidays,
                                         visibleMonth: $model.month, selectedDates: model.candidates.selected,
                                         onSelect: { date in model.chooseCandidate(date) },
                                         showsAdjacentDays: true, showsHolidayNames: true, rowHeight: 48)
                                .disabled(model.defaultHourSelection.anchor != nil)
                            Text(model.candidates.mode == .multiple ? "日付をクリックして追加・解除できます。月をまたいで選べます。" : "日付を1つ選んでください。").font(theme.font(11)).foregroundStyle(.secondary)
                            if let notice = model.holidayNotice { Text(notice).font(theme.font(11)).foregroundStyle(.orange) }
                        }
                    }.frame(minWidth: 390)
                    ToolCard {
                        VStack(alignment: .leading, spacing: 16) {
                            ToolSectionLabel(title: "候補の設定", symbol: "slider.horizontal.3")
                            ThemePicker("選択モード", selection: $model.candidates.mode, options: ScheduleCandidates.Mode.allCases.map { ($0, $0.rawValue) }, tabs: true)
                            Text("新しく選ぶ日付に使う時間").font(theme.font(11)).foregroundStyle(.secondary)
                            HourRangeBar(title: "新しい候補の時間", hours: $model.candidates.defaults, selection: $model.defaultHourSelection)
                            Divider()
                            HStack { Text("選択中：\(model.candidates.selected.count)件"); Spacer(); Button("すべて解除") { model.clearCandidates() }.disabled(model.candidates.selected.isEmpty) }.font(theme.font(11))
                            if model.candidates.dates.isEmpty { Text("カレンダーで候補日を選ぶと、日付ごとの時間を変更できます。").font(theme.font(11)).foregroundStyle(.secondary) }
                            ForEach(model.candidates.dates, id: \.self) { date in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack { Text(dateLabel(date)).font(theme.font(12, weight: .semibold)); Spacer(); Button("解除") { model.removeCandidate(date) }.accessibilityLabel(BusinessDays.key(date) + "の候補を解除") }
                                    HourRangeBar(title: dateLabel(date) + "の時間", hours: hoursBinding(date), selection: hourSelectionBinding(date))
                                }.padding(.vertical, 4)
                            }
                            if model.hasPendingHours { Text("時間バーの終了点を選ぶと出力できます。").font(theme.font(11)).foregroundStyle(theme.accent) }
                            if !model.candidates.invalidDates.isEmpty { Text("終了時間は開始時間より後にしてください。すべての候補が有効になるまでコピーできません。").font(theme.font(11)).foregroundStyle(.red) }
                        }
                    }.frame(minWidth: 360)
                }
                ToolCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            ToolSectionLabel(title: "出力テキスト", symbol: "doc.text")
                            Spacer()
                            Text(model.candidateStatus).font(theme.font(11)).foregroundStyle(.secondary)
                            Button("テキストをコピー") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output, forType: .string); model.candidateStatus = "コピーしました" }
                                .buttonStyle(ThemeButtonStyle(prominent: true)).disabled(output.isEmpty)
                        }
                        ToolTextEditor(text: .constant(output), editable: false, label: "日程候補の出力テキスト").frame(height: 110)
                    }
                }
                CalendarHolidayEditor(model: model)
                ToolFootnote(text: "時間は9〜21時の1時間単位。バーの開始点・終了点をクリックすると、選んだ時間帯を塗って表示します。候補は日付順に並び、複数候補モードでは行頭に「・」を付けます。入力はこのウィンドウ内だけで保持し、カレンダーアプリへの登録や外部送信は行いません。")
            }.padding(24)
        }.onChange(of: model.candidates) { _, _ in model.candidateStatus = "" }
            .onChange(of: model.defaultHourSelection) { _, _ in model.candidateStatus = "" }
    }
    private func dateLabel(_ date: Date) -> String {
        let c = BusinessDays.calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year!)年\(c.month!)月\(c.day!)日"
    }
    private func hoursBinding(_ date: Date) -> Binding<ScheduleCandidates.Hours> {
        Binding(get: { model.candidates.time(for: date) }, set: { model.candidates.setTime($0, for: date) })
    }
    private func hourSelectionBinding(_ date: Date) -> Binding<ScheduleCandidates.HourSelection> {
        Binding(get: { model.hourSelections[date] ?? .init() }, set: { model.hourSelections[date] = $0; model.candidateStatus = "" })
    }
}
