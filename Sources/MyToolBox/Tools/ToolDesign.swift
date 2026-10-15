import SwiftUI

/// Shared visual language for utility windows. Uses system materials and dynamic colors.
struct ToolPage<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    var content: Content
    init(_ title: String, subtitle: String, symbol: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title; self.subtitle = subtitle; self.symbol = symbol; self.tint = tint; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 25, weight: .medium)).foregroundStyle(tint)
                    .frame(width: 56, height: 56).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 25, weight: .bold, design: .rounded))
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Label("LOCAL", systemImage: "lock.shield").font(.system(size: 10, weight: .semibold)).tracking(1)
                    .foregroundStyle(.secondary).padding(.horizontal, 10).padding(.vertical, 7)
                    .background(.quaternary.opacity(0.5), in: Capsule())
            }.padding(.horizontal, 26).padding(.vertical, 22).fixedSize(horizontal: false, vertical: true)
            Divider().opacity(0.5)
            content
        }.background(Color(nsColor: .windowBackgroundColor)).tint(tint)
    }
}
struct ToolCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.06)))
    }
}
struct ToolSectionLabel: View {
    var title: String
    var symbol: String
    var body: some View { Label(title, systemImage: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary) }
}
struct ToolFootnote: View {
    let text: String
    var body: some View { Label(text, systemImage: "info.circle").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
}
struct AudioAction: View {
    var title: String
    var subtitle: String
    var symbol: String
    var tint: Color = .cyan
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 30, weight: .light)).frame(height: 36).foregroundStyle(tint)
                Text(title).font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 24)
                .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.2)))
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }
}

struct ToolCalendar: View {
    @Binding var selection: Date
    var holidays: [String: String]
    @State private var month = Date()
    private let calendar = BusinessDays.calendar
    private var first: Date { calendar.dateInterval(of: .month, for: month)!.start }
    private var offset: Int { calendar.component(.weekday, from: first) - 1 }
    private var days: Int { calendar.range(of: .day, in: .month, for: first)!.count }
    private var monthTitle: String { "\(calendar.component(.year, from: month))年\(calendar.component(.month, from: month))月" }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(monthTitle).font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("前の月")
                Button { month = Date(); selection = Date() } label: { Circle().fill(.secondary).frame(width: 6, height: 6).frame(width: 18, height: 18) }.help("今日")
                Button { shift(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("次の月")
            }.buttonStyle(.plain).foregroundStyle(.secondary)
            GeometryReader { geometry in
                let cellWidth = max(1, (geometry.size.width - 18) / 7)
                VStack(spacing: 4) {
                    HStack(spacing: 3) {
                        ForEach(Array(["日", "月", "火", "水", "木", "金", "土"].enumerated()), id: \.offset) { i, label in Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(i == 0 ? Color.red.opacity(0.7) : i == 6 ? .blue.opacity(0.8) : .secondary).frame(width: cellWidth, height: 20) }
                    }
                    ForEach(0..<6) { row in
                        HStack(spacing: 3) {
                            ForEach(0..<7) { column in
                                dayCell(row * 7 + column).frame(width: cellWidth, height: 29)
                            }
                        }
                    }
                }
            }.frame(height: 218)
        }.onAppear { month = selection }.onChange(of: selection) { _, date in month = date }
    }
    @ViewBuilder private func dayCell(_ cell: Int) -> some View {
        let day = cell - offset + 1
        if day > 0 && day <= days {
            let date = calendar.date(byAdding: .day, value: day - 1, to: first)!
            let selected = calendar.isDate(date, inSameDayAs: selection)
            let holiday = holidays[BusinessDays.key(date)]
            Button { selection = date } label: {
                VStack(spacing: 2) {
                    Text("\(day)").font(.system(size: 12, weight: selected ? .bold : .regular, design: .rounded))
                    Circle().fill(holiday == nil ? Color.clear : selected ? .white : .red.opacity(0.75)).frame(width: 3, height: 3)
                }.frame(maxWidth: .infinity).frame(height: 29)
                    .foregroundStyle(selected ? Color.black : holiday != nil || cell % 7 == 0 ? .red.opacity(0.85) : cell % 7 == 6 ? .blue : .primary)
                    .background(selected ? Color.mint : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(calendar.isDateInToday(date) && !selected ? Color.mint.opacity(0.7) : .clear))
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).help(holiday ?? BusinessDays.key(date)).accessibilityLabel(BusinessDays.key(date) + (holiday.map { " " + $0 } ?? ""))
        } else { Color.clear }
    }
    private func shift(_ delta: Int) { month = calendar.date(byAdding: .month, value: delta, to: first)! }
}
