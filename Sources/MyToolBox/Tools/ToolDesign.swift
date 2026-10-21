import SwiftUI

/// Shared visual language for utility windows. Uses system materials and dynamic colors.
struct ToolPage<Content: View>: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let usesNetwork: Bool
    var content: Content
    init(_ title: String, subtitle: String, symbol: String, tint: Color, usesNetwork: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title; self.subtitle = subtitle; self.symbol = symbol; self.tint = tint; self.usesNetwork = usesNetwork; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Group {
                    if theme.classic { ClassicToolIcon(symbol: symbol).frame(width: 24, height: 24) }
                    else {
                        Image(systemName: symbol).font(theme.font(25, weight: .medium)).foregroundStyle(tint)
                            .frame(width: 56, height: 56).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(theme.font( 25, weight: .bold, design: .rounded))
                    Text(subtitle).font(theme.font( 12)).foregroundStyle(.secondary)
                }
                Spacer()
                ThemeMenu()
                Label(usesNetwork ? "NETWORK" : "LOCAL", systemImage: usesNetwork ? "network" : "lock.shield").font(theme.font( 10, weight: .semibold)).tracking(1)
                    .foregroundStyle(.secondary).padding(.horizontal, 10).padding(.vertical, 7)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 50))
            }.padding(.horizontal, 26).padding(.vertical, theme.classic ? 8 : 22).fixedSize(horizontal: false, vertical: true)
            Divider().opacity(0.5)
            content
        }.tint(theme.classic ? theme.accent : tint)
    }
}
struct ToolCard<Content: View>: View {
    @Environment(\.appTheme) private var theme
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius))
            .overlay(RoundedRectangle(cornerRadius: theme.radius).strokeBorder(theme.edge.opacity(0.14)))
            .classicBevel()
    }
}
struct ToolSectionLabel: View {
    @Environment(\.appTheme) private var theme
    var title: String
    var symbol: String
    var body: some View { Label(title, systemImage: symbol).font(theme.font( 12, weight: .semibold)).foregroundStyle(.secondary) }
}
struct ToolFootnote: View {
    @Environment(\.appTheme) private var theme
    let text: String
    var body: some View { Label(text, systemImage: "info.circle").font(theme.font( 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
}
struct AudioAction: View {
    @Environment(\.appTheme) private var theme
    var title: String
    var subtitle: String
    var symbol: String
    var tint: Color = .cyan
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: symbol).font(theme.font( 30, weight: .light)).frame(height: 36).foregroundStyle(theme.classic ? theme.accent : tint)
                Text(title).font(theme.font( 17, weight: .semibold, design: .rounded))
                Text(subtitle).font(theme.font(11)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 24)
                .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 16))
                .overlay(RoundedRectangle(cornerRadius: theme.classic ? 0 : 16).strokeBorder(tint.opacity(0.2)))
                .contentShape(RoundedRectangle(cornerRadius: theme.classic ? 0 : 16))
        }.buttonStyle(ThemeButtonStyle(plain: true))
    }
}

struct ToolCalendar: View {
    @Environment(\.appTheme) private var theme
    @Binding var selection: Date
    var holidays: [String: String]
    @State private var month = Date()
    var visibleMonth: Binding<Date>? = nil
    var selectedDates: Set<Date>? = nil
    var onSelect: ((Date) -> Void)? = nil
    var showsAdjacentDays = false
    var showsHolidayNames = false
    var showsCellBorders = false
    var rowHeight: CGFloat = 29
    var textScale: CGFloat = 1
    private var displayedMonth: Date {
        get { visibleMonth?.wrappedValue ?? month }
        nonmutating set { if let visibleMonth { visibleMonth.wrappedValue = newValue } else { month = newValue } }
    }
    private let calendar = BusinessDays.calendar
    private var first: Date { calendar.dateInterval(of: .month, for: displayedMonth)!.start }
    private var offset: Int { calendar.component(.weekday, from: first) - 1 }
    private var days: Int { calendar.range(of: .day, in: .month, for: first)!.count }
    private var monthTitle: String { "\(calendar.component(.year, from: displayedMonth))年\(calendar.component(.month, from: displayedMonth))月" }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(monthTitle).font(theme.font( 14 * textScale, weight: .semibold, design: .rounded))
                Spacer()
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("前の月")
                Button { displayedMonth = Date(); if onSelect == nil { selection = Date() } } label: { Circle().fill(.secondary).frame(width: 6, height: 6).frame(width: 18, height: 18) }.help("今日").accessibilityLabel("今月を表示")
                Button { shift(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("次の月")
            }.buttonStyle(ThemeButtonStyle(plain: true)).foregroundStyle(.secondary)
            GeometryReader { geometry in
                let cellWidth = max(1, (geometry.size.width - 18) / 7)
                VStack(spacing: 4) {
                    HStack(spacing: 3) {
                        ForEach(Array(["日", "月", "火", "水", "木", "金", "土"].enumerated()), id: \.offset) { i, label in Text(label).font(theme.font( 10 * textScale, weight: .medium)).foregroundStyle(i == 0 ? Color.red.opacity(0.7) : i == 6 ? .blue.opacity(0.8) : .secondary).frame(width: cellWidth, height: 20) }
                    }
                    ForEach(0..<6) { row in
                        HStack(spacing: 3) {
                            ForEach(0..<7) { column in
                                dayCell(row * 7 + column).frame(width: cellWidth, height: rowHeight)
                            }
                        }
                    }
                }
            }.frame(height: 20 + 6 * (rowHeight + 4))
        }.onAppear { if visibleMonth == nil { month = selection } }.onChange(of: selection) { _, date in if visibleMonth == nil { month = date } }
    }
    @ViewBuilder private func dayCell(_ cell: Int) -> some View {
        let day = cell - offset + 1
        if showsAdjacentDays || day > 0 && day <= days {
            let date = calendar.date(byAdding: .day, value: day - 1, to: first)!
            let selected = selectedDates?.contains(calendar.startOfDay(for: date)) ?? calendar.isDate(date, inSameDayAs: selection)
            let holiday = holidays[BusinessDays.key(date)]
            Button {
                if let onSelect { onSelect(date); displayedMonth = date } else { selection = date }
            } label: {
                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))").font(theme.font( 12 * textScale, weight: selected ? .bold : .regular, design: .rounded))
                    if showsHolidayNames, let holiday { Text(holiday).font(theme.font(8 * textScale)).lineLimit(1) }
                    Circle().fill(holiday == nil ? Color.clear : selected ? .white : .red.opacity(0.75)).frame(width: 3, height: 3)
                }.frame(maxWidth: .infinity).frame(height: rowHeight)
                    .foregroundStyle(selected ? (theme.classic ? Color.white : Color.black) : holiday != nil || cell % 7 == 0 ? .red.opacity(0.85) : cell % 7 == 6 ? .blue : .primary)
                    .background(selected ? (theme.classic ? theme.accent : Color.mint) : Color.clear, in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 8))
                    .overlay(RoundedRectangle(cornerRadius: theme.classic ? 0 : 8).strokeBorder(calendar.isDateInToday(date) && !selected ? (theme.classic ? theme.accent : Color.mint).opacity(0.7) : .clear))
                    .overlay(RoundedRectangle(cornerRadius: theme.classic ? 0 : 8).strokeBorder(showsCellBorders ? Color.primary.opacity(theme.classic ? 0.3 : 0.2) : .clear, lineWidth: 1))
                    .contentShape(Rectangle())
            }.buttonStyle(ThemeButtonStyle(plain: true)).opacity(day > 0 && day <= days ? 1 : 0.45).accessibilityValue(selected ? "選択中" : "未選択").help(holiday ?? BusinessDays.key(date)).accessibilityLabel(BusinessDays.key(date) + (holiday.map { " " + $0 } ?? ""))
        } else { Color.clear }
    }
    private func shift(_ delta: Int) { displayedMonth = calendar.date(byAdding: .month, value: delta, to: first)! }
}

/// Resizes only its own resizable window; borderless offscreen previews keep their test dimensions.
struct ExpandableToolWindowSizing: NSViewRepresentable {
    var expanded: Bool
    var compactSize = NSSize(width: 360, height: 520)
    final class Host: NSView {
        var expanded = false
        var compactSize = NSSize(width: 360, height: 520)
        var applied: Bool?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); apply() }
        func apply() {
            guard let window, window.styleMask.contains(.resizable), applied != expanded else { return }
            applied = expanded
            let desired = expanded ? NSSize(width: 1100, height: 850) : compactSize
            let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 1000)
            let top = window.frame.maxY
            window.setContentSize(NSSize(width: min(desired.width, visible.width - 20), height: min(desired.height, visible.height - 50)))
            var frame = window.frame
            frame.origin.x = min(max(visible.minX, frame.minX), max(visible.minX, visible.maxX - frame.width))
            frame.origin.y = min(max(visible.minY, top - frame.height), max(visible.minY, visible.maxY - frame.height))
            window.setFrame(frame, display: false)
        }
    }
    func makeNSView(context: Context) -> Host { let host = Host(); host.expanded = expanded; host.compactSize = compactSize; return host }
    func updateNSView(_ view: Host, context: Context) {
        view.expanded = expanded; view.compactSize = compactSize
        DispatchQueue.main.async { view.apply() }
    }
}
