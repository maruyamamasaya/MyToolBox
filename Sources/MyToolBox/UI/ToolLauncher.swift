import SwiftUI

struct ToolLauncher: View {
    static var preferredHeight: CGFloat { min(680, 148 + CGFloat((ToolID.allCases.count + 4) / 5) * 98) }
    var openTool: (ToolID) -> Void
    var openMonitorSettings: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text("MyToolBox").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("いつもの道具を、このMacに。").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(ToolID.allCases.count) TOOLS").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(.tertiary)
            }.padding(22)
            Divider().opacity(0.5)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 8) {
                    ForEach(ToolID.allCases) { tool in
                        Button { openTool(tool) } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(color(tool).opacity(0.14))
                                    Image(systemName: tool.symbol)
                                        .font(.system(size: 27, weight: .medium))
                                        .foregroundStyle(color(tool))
                                }.frame(width: 44, height: 44)
                                Text(tool.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(height: 28, alignment: .top)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 90)
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain).help(tool.subtitle).accessibilityLabel(tool.title).accessibilityHint("ツールを開く。" + tool.subtitle)
                    }
                }.padding(.horizontal, 16).padding(.vertical, 16)
            }
            Divider().opacity(0.5)
            HStack {
                Button(action: openMonitorSettings) { Label("モニター設定", systemImage: "gearshape") }
                Spacer()
                Button("終了") { NSApp.terminate(nil) }
            }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 22).padding(.vertical, 14)
        }.frame(width: 440, height: Self.preferredHeight).background(Color(nsColor: .windowBackgroundColor))
    }
    private func color(_ tool: ToolID) -> Color {
        switch tool {
        case .systemMonitor: return .green
        case .businessDays: return Color(red: 0.02, green: 0.65, blue: 0.47)
        case .audioCheck: return Color(red: 0.0, green: 0.62, blue: 0.87)
        case .microphoneCheck: return .purple
        case .csvViewer: return .blue
        case .csvEditor: return .orange
        case .sequentialText: return .indigo
        case .clipboardFormatter: return .teal
        case .textCleaner: return .pink
        case .lineTools: return Color(red: 0.77, green: 0.48, blue: 0.09)
        case .stringReplacer: return Color(red: 0.89, green: 0.23, blue: 0.27)
        case .comparison: return Color(red: 0.23, green: 0.43, blue: 0.94)
        }
    }
}
