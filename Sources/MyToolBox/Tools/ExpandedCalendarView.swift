import SwiftUI

struct ExpandedCalendarView: View {
    @Environment(\.appTheme) private var theme
    @Binding var month: Date
    @Binding var selected: Date
    let holidays: [String: String]
    var settings: () -> AnyView = { AnyView(EmptyView()) }
    private let calendar = BusinessDays.calendar
    private let weekdays = ["SUN 日", "MON 月", "TUE 火", "WED 水", "THU 木", "FRI 金", "SAT 土"]
    private var first: Date { calendar.dateInterval(of: .month, for: month)!.start }
    private var year: Int { calendar.component(.year, from: month) }
    private var monthNumber: Int { calendar.component(.month, from: month) }
    private var monthName: String { ["睦月", "如月", "弥生", "卯月", "皐月", "水無月", "文月", "葉月", "長月", "神無月", "霜月", "師走"][monthNumber - 1] }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button { shift(-1) } label: { Label("前月", systemImage: "chevron.left") }
                Button("今日") { month = Date(); selected = Date() }
                Button { shift(1) } label: { Label("翌月", systemImage: "chevron.right") }
                Spacer()
                Text("マイカレンダー").font(theme.font(12)).foregroundStyle(.secondary)
                Spacer()
                ThemeMenu()
                settings()
            }.buttonStyle(ThemeButtonStyle(plain: true)).font(theme.font(12))
            HStack(alignment: .top, spacing: 18) {
                miniMonth(-2)
                miniMonth(-1)
                VStack(spacing: 1) {
                    Text(verbatim: "\(year)").font(theme.font(18, weight: .semibold))
                    Text(verbatim: "\(monthNumber)").font(theme.font(70, weight: .bold, design: .rounded)).foregroundStyle(.pink)
                    Text(month.formatted(.dateTime.month(.wide).locale(Locale(identifier: "en_US"))).uppercased()).font(theme.font(11, weight: .semibold))
                    Text(monthName).font(theme.font(12)).foregroundStyle(.secondary)
                }.frame(width: 112)
                miniMonth(1)
                miniMonth(2)
                miniMonth(3)
            }.frame(height: 158)
            GeometryReader { geometry in
                let cellWidth = geometry.size.width / 7
                let cellHeight = max(68, (geometry.size.height - 30) / 6)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(0..<7) { column in
                            Text(weekdays[column]).font(theme.font(13, weight: .bold))
                                .foregroundStyle(column == 0 ? Color.red : column == 6 ? .blue : .primary)
                                .frame(width: cellWidth, height: 30)
                                .background(column == 0 ? Color.red.opacity(0.14) : column == 6 ? Color.blue.opacity(0.14) : Color.primary.opacity(0.06))
                        }
                    }
                    ForEach(0..<6) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<7) { column in
                                dayCell(row * 7 + column, width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
            }
            HStack {
                Text(selected.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: Locale(identifier: "ja_JP"), calendar: calendar, timeZone: calendar.timeZone)))
                Spacer()
                Text(CalendarAlmanac.supportedYears.contains(year) ? "六曜・二十四節気・月齢（正午）" : "暦注データは2024〜2027年に対応")
                    .foregroundStyle(.secondary)
            }.font(theme.font(11))
        }.padding(22)
            .frame(minWidth: 1000, idealWidth: 1080, minHeight: 820, idealHeight: 850)
            .environment(\.calendar, calendar).environment(\.timeZone, calendar.timeZone)
    }

    private func shift(_ amount: Int) { month = calendar.date(byAdding: .month, value: amount, to: first)! }

    private func dayCell(_ cell: Int, width: CGFloat, height: CGFloat) -> some View {
        let date = calendar.date(byAdding: .day, value: cell - calendar.component(.weekday, from: first) + 1, to: first)!
        let current = calendar.isDate(date, equalTo: first, toGranularity: .month)
        let holiday = holidays[BusinessDays.key(date)]
        let annotation = CalendarAlmanac.annotation(for: date)
        let weekend = cell % 7
        let color: Color = weekend == 0 || holiday != nil ? .red : weekend == 6 ? .blue : .primary
        let today = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selected)
        return Button { selected = date } label: {
            ExpandedCalendarDay(date: date, annotation: annotation, holiday: holiday, color: color, today: today)
                .padding(8).frame(width: width, height: height, alignment: .topLeading)
                .opacity(current ? 1 : 0.28)
                .background(weekend == 0 || holiday != nil ? Color.red.opacity(0.09) : weekend == 6 ? Color.blue.opacity(0.09) : theme.surface.opacity(0.6))
                .overlay(Rectangle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                .overlay(Rectangle().strokeBorder(isSelected ? theme.accent : .clear, lineWidth: 2))
                .contentShape(Rectangle())
        }.buttonStyle(ThemeButtonStyle(plain: true))
            .accessibilityLabel(([BusinessDays.key(date), holiday, annotation.rokuyo, annotation.solarTerm, annotation.moonPhase].compactMap { $0 }).joined(separator: " "))
            .accessibilityValue(isSelected ? "選択中" : "未選択")
    }

    private func miniMonth(_ offset: Int) -> some View {
        let date = calendar.date(byAdding: .month, value: offset, to: first)!
        let start = calendar.component(.weekday, from: date) - 1
        let count = calendar.range(of: .day, in: .month, for: date)!.count
        return Button { month = date } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: "\(calendar.component(.year, from: date))年 \(calendar.component(.month, from: date))月").font(theme.font(10, weight: .semibold))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 3) {
                    ForEach(0..<7) { i in Text(["日", "月", "火", "水", "木", "金", "土"][i]).foregroundStyle(i == 0 ? Color.red : i == 6 ? .blue : .secondary) }
                    ForEach(0..<42) { i in
                        let day = i - start + 1
                        let d = calendar.date(byAdding: .day, value: day - 1, to: date)!
                        Text(day > 0 && day <= count ? String(day) : " ")
                            .foregroundStyle(i % 7 == 0 || holidays[BusinessDays.key(d)] != nil ? Color.red : i % 7 == 6 ? .blue : .primary)
                    }
                }.font(theme.font(9)).monospacedDigit()
            }.frame(maxWidth: .infinity)
        }.buttonStyle(ThemeButtonStyle(plain: true)).accessibilityLabel("\(calendar.component(.year, from: date))年\(calendar.component(.month, from: date))月へ移動")
    }
}

private struct ExpandedCalendarDay: View {
    @Environment(\.appTheme) private var theme
    let date: Date
    let annotation: CalendarAlmanac.Annotation
    let holiday: String?
    let color: Color
    let today: Bool
    private var ageText: String { annotation.moonAge.map { "月齢 " + String(format: "%.1f", $0) } ?? "" }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 7) {
                Text(verbatim: String(BusinessDays.calendar.component(.day, from: date)))
                    .font(theme.font(28, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(today ? Color.white : color)
                    .padding(.horizontal, today ? 4 : 0)
                    .background(today ? Color.red : .clear, in: RoundedRectangle(cornerRadius: 6))
                labels
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            HStack {
                Text(ageText).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(annotation.moonPhase ?? "")
            }.font(theme.font(9))
        }
    }
    private var labels: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let rokuyo = annotation.rokuyo { Text(rokuyo).foregroundStyle(.secondary) }
            if let term = annotation.solarTerm { Text(term) }
            if let holiday { Text(holiday).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
        }.font(theme.font(10))
    }
}
