import SwiftUI

struct HourRangeBar: View {
    @Environment(\.appTheme) private var theme
    let title: String
    @Binding var hours: ScheduleCandidates.Hours
    @Binding var selection: ScheduleCandidates.HourSelection
    @State private var hoveredHour: Int?
    private let bounds = ScheduleCandidates.HourSelection.bounds
    private var preview: ClosedRange<Int>? {
        if let anchor = selection.anchor {
            if let hoveredHour, hoveredHour != anchor { return min(anchor, hoveredHour)...max(anchor, hoveredHour) }
            return nil
        }
        return hours.start...max(hours.start, hours.end)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                if let anchor = selection.anchor {
                    Text("開始点 \(ScheduleCandidates.Hours.label(anchor)) → 終了点を選択")
                    Spacer(minLength: 4)
                    Button("キャンセル") { selection.cancel(); hoveredHour = nil }.controlSize(.small)
                } else {
                    Text("\(ScheduleCandidates.Hours.label(hours.start)) 〜 \(ScheduleCandidates.Hours.label(hours.end))")
                        .monospacedDigit()
                    Spacer(minLength: 4)
                    Text("\(max(0, hours.end - hours.start))時間").foregroundStyle(.secondary)
                }
            }.font(theme.font(11, weight: .medium))
            GeometryReader { geometry in
                let inset: CGFloat = 12
                let span = max(1, geometry.size.width - inset * 2)
                let step = span / CGFloat(bounds.upperBound - bounds.lowerBound)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: theme.classic ? 0 : 5).fill(theme.edge.opacity(0.18))
                        .frame(width: span, height: 10).offset(x: inset, y: 6)
                    if let preview {
                        let lower = min(bounds.upperBound, max(bounds.lowerBound, preview.lowerBound))
                        let upper = min(bounds.upperBound, max(bounds.lowerBound, preview.upperBound))
                        Rectangle().fill(theme.accent.opacity(selection.anchor == nil ? 0.65 : 0.35))
                            .frame(width: max(0, CGFloat(upper - lower) * step), height: 10)
                            .offset(x: inset + CGFloat(lower - bounds.lowerBound) * step, y: 6)
                    }
                    ForEach(Array(bounds), id: \.self) { hour in
                        Button { choose(hour) } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Rectangle().fill(theme.edge.opacity(0.65)).frame(width: 1, height: 10)
                                    if hour == selection.anchor || selection.anchor == nil && (hour == hours.start || hour == hours.end) {
                                        RoundedRectangle(cornerRadius: theme.classic ? 0 : 7).fill(theme.accent).frame(width: 12, height: 16)
                                            .overlay(RoundedRectangle(cornerRadius: theme.classic ? 0 : 7).stroke(theme.classic ? Color.black : theme.text.opacity(0.75), lineWidth: 1))
                                    }
                                }.frame(height: 22)
                                Text(String(hour)).font(theme.font(10, weight: preview?.contains(hour) == true ? .bold : .regular)).monospacedDigit()
                            }.foregroundStyle(theme.text).frame(width: max(24, step), height: 50, alignment: .top).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .offset(x: inset + CGFloat(hour - bounds.lowerBound) * step - max(24, step) / 2)
                            .onHover { inside in if inside { hoveredHour = hour } else if hoveredHour == hour { hoveredHour = nil } }
                            .accessibilityLabel(title + "：\(hour)時を" + (selection.anchor == nil ? "開始点にする" : "終了点にする"))
                            .accessibilityValue(hour == selection.anchor ? "開始点を選択中" : preview?.contains(hour) == true ? "選択範囲内" : "")
                    }
                }
            }.frame(height: 50)
            Text(selection.anchor == nil ? "開始 → 終了の順にクリック" : "異なる時刻をクリックして確定（逆順でも選択できます）")
                .font(theme.font(10)).foregroundStyle(.secondary)
        }.accessibilityElement(children: .contain).accessibilityLabel(title)
            .onExitCommand { selection.cancel(); hoveredHour = nil }
    }
    private func choose(_ hour: Int) {
        if let range = selection.click(hour) { hours = range }
        hoveredHour = nil
    }
}
