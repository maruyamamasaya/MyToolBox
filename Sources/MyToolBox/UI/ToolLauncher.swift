import SwiftUI

struct ToolLauncher: View {
    static var preferredHeight: CGFloat { min(680, max(550, 156 + CGFloat((ToolID.allCases.count + 2) / 3) * 118)) }
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 16) {
                    ForEach(ToolID.allCases) { tool in
                        Button { openTool(tool) } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 22).fill(color(tool).gradient)
                                    RoundedRectangle(cornerRadius: 22).fill(LinearGradient(colors: [.white.opacity(0.16), .clear, .black.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    Image(systemName: tool.symbol).font(.system(size: 30, weight: .medium)).foregroundStyle(.white).shadow(color: .black.opacity(0.12), radius: 2, y: 2)
                                }.frame(width: 68, height: 68)
                                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.18)))
                                    .shadow(color: color(tool).opacity(0.16), radius: 8, y: 5)
                                Text(tool.title).font(.system(size: 11, weight: .medium)).multilineTextAlignment(.center).lineLimit(2).frame(height: 26, alignment: .top)
                            }.frame(maxWidth: .infinity).contentShape(Rectangle())
                        }.buttonStyle(.plain).help(tool.subtitle).accessibilityLabel(tool.title).accessibilityHint("ツールを開く。" + tool.subtitle)
                    }
                }.padding(.horizontal, 24).padding(.vertical, 20)
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
        }
    }
}
