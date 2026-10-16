import SwiftUI
import UniformTypeIdentifiers

struct ToolLauncher: View {
    @Environment(\.appTheme) private var theme
    static let preferredWidth: CGFloat = 560
    static var preferredHeight: CGFloat { 740 }
    @AppStorage(ToolFavorites.storageKey) private var favoritesRaw = "[]"
    private var favorites: Set<String> { ToolFavorites.decode(favoritesRaw) }
    @State private var query = ""
    @State private var category: ToolCategory?
    @State private var draggedFavorite: String?
    @State private var dropTarget: String?
    private var visibleTools: [ToolID] {
        ToolID.allCases.filter { (category == nil || $0.category == category) && $0.matches(query) }
    }
    var openTool: (ToolID) -> Void
    var openMonitorSettings: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text("MyToolBox").font(theme.font( 20, weight: .bold, design: .rounded))
                    Text("いつもの道具を、このMacに。").font(theme.font( 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(ToolID.allCases.count) TOOLS").font(theme.font( 9, weight: .semibold)).tracking(1).foregroundStyle(.tertiary)
            }.padding(22).background { if theme.classic { theme.surface.overlay(ClassicBevel()) } }
            Divider().opacity(0.5)
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("ツール名・用途で検索", text: $query).textFieldStyle(.plain)
                        .accessibilityLabel("ツールを検索")
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).accessibilityLabel("検索をクリア")
                    }
                }.padding(10).background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 8))
                HStack {
                    Picker("カテゴリ", selection: $category) {
                        Text("すべて").tag(Optional<ToolCategory>.none)
                        ForEach(ToolCategory.allCases) { item in Text(item.rawValue).tag(Optional(item)) }
                    }.labelsHidden().accessibilityLabel("カテゴリ")
                    Spacer()
                    Text("\(visibleTools.count)件").foregroundStyle(.secondary)
                }
            }.font(theme.font(12)).padding(.horizontal, 20).padding(.vertical, 12)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Color.clear.frame(height: 0).id("top")
                        if visibleTools.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "magnifyingglass").font(theme.font(24))
                                Text("該当するツールがありません")
                                Text("検索語やカテゴリを変えてください").font(theme.font(11)).foregroundStyle(.secondary)
                                Button("絞り込みを解除") { query = ""; category = nil }
                            }.frame(maxWidth: .infinity).padding(.vertical, 35)
                        }
                        let pinned = ToolFavorites.ordered(favoritesRaw).compactMap { id in visibleTools.first { $0.rawValue == id } }
                        if !pinned.isEmpty {
                            toolSection("お気に入り", tools: pinned, favoriteSection: true)
                        }
                        ForEach(ToolCategory.allCases) { section in
                            let tools = visibleTools.filter { $0.category == section }
                            if !tools.isEmpty {
                                toolSection(section.rawValue, tools: tools)
                            }
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 16)
                }
                .onChange(of: query) { _, _ in proxy.scrollTo("top", anchor: .top) }
                .onChange(of: category) { _, _ in proxy.scrollTo("top", anchor: .top) }
            }
            Divider().opacity(0.5)
            HStack {
                ThemeMenu()
                Button(action: openMonitorSettings) { Label("設定", systemImage: "gearshape") }
                Spacer()
                Text("監視はバックグラウンドで継続").font(theme.font(9)).foregroundStyle(.secondary)
            }.buttonStyle(ThemeButtonStyle(plain: true)).font(theme.font( 11)).foregroundStyle(.secondary).padding(.horizontal, 22).padding(.vertical, 14).background { if theme.classic { theme.surface.overlay(ClassicBevel()) } }
        }.frame(width: Self.preferredWidth, height: Self.preferredHeight).background(theme.classic ? theme.background : .clear)
    }
    private func toolSection(_ title: String, tools: [ToolID], favoriteSection: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if favoriteSection { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                Text(title).font(theme.font(12, weight: .semibold))
                Text("\(tools.count)").font(theme.font(10)).foregroundStyle(.secondary)
                if favoriteSection { Text("ドラッグで並べ替え").font(theme.font(10)).foregroundStyle(.secondary) }
                Rectangle().fill(theme.text.opacity(0.12)).frame(height: 1)
            }.accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 8) {
                ForEach(tools) { tool in
                    if favoriteSection {
                        toolButton(tool)
                            .onDrag {
                                draggedFavorite = tool.rawValue
                                let provider = NSItemProvider()
                                provider.registerDataRepresentation(forTypeIdentifier: UTType.myToolBoxFavorite.identifier, visibility: .ownProcess) { completion in
                                    completion(Data(tool.rawValue.utf8), nil); return nil
                                }
                                return provider
                            }
                            .onDrop(of: [.myToolBoxFavorite], delegate: FavoriteDropDelegate(
                                target: tool.rawValue, raw: $favoritesRaw, dragged: $draggedFavorite, highlighted: $dropTarget))
                            .background(RoundedRectangle(cornerRadius: theme.classic ? 0 : 8).fill(dropTarget == tool.rawValue ? theme.accent.opacity(0.2) : .clear))
                    } else { toolButton(tool) }
                }
            }
        }
    }
    private func toolButton(_ tool: ToolID) -> some View {
        ZStack(alignment: .topTrailing) {
                        Button { openTool(tool) } label: {
                            VStack(spacing: 8) {
                                Group {
                                    if theme.classic { ClassicToolIcon(symbol: tool.symbol).frame(width: 32, height: 32).frame(width: 44, height: 44) }
                                    else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10).fill(color(tool).opacity(0.14))
                                            Image(systemName: tool.symbol).font(theme.font(27, weight: .medium)).foregroundStyle(color(tool))
                                        }.frame(width: 44, height: 44)
                                    }
                                }
                                Text(tool.title)
                                    .font(theme.font( 10, weight: .medium))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(height: 28, alignment: .top)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 90)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()
                        .foregroundStyle(theme.classic ? Color.white : theme.text).help(tool.subtitle).accessibilityLabel(tool.title).accessibilityHint("ツールを開く。" + tool.subtitle)
            Button {
                favoritesRaw = ToolFavorites.toggling(tool.rawValue, in: favoritesRaw)
            } label: {
                Image(systemName: favorites.contains(tool.rawValue) ? "star.fill" : "star")
                    .font(theme.font(12, weight: .semibold))
                    .foregroundStyle(favorites.contains(tool.rawValue) ? Color.yellow : theme.text.opacity(0.5))
                    .frame(width: 24, height: 24).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .help(favorites.contains(tool.rawValue) ? "お気に入りから解除" : "お気に入りに登録")
                .accessibilityLabel(tool.title + (favorites.contains(tool.rawValue) ? "をお気に入りから解除" : "をお気に入りに登録"))
        }
    }

    private func color(_ tool: ToolID) -> Color {
        switch tool {
        case .gitBatch: return .orange
        case .sqlWorkspace: return .indigo
        case .regexTester, .regexBuilder: return .indigo
        case .tableBuilder, .csvStatistics: return .teal
        case .jsonWorkspace, .logHighlighter: return .orange
        case .cidrAnalyzer, .dnsRecordBuilder, .unitConverter, .percentageCalculator, .simpleCalculator, .numberCalculator, .cronReader, .linuxCommands, .chmodCalculator, .directoryTree, .unixTimeConverter: return .cyan
        case .byteConverter, .numberBaseConverter, .bandwidthCalculator, .raidCalculator, .slaCalculator: return .cyan
        case .randomNumberGenerator: return .purple
        case .portNumberFinder, .httpStatusViewer: return .cyan
        case .hashGenerator: return .purple
        case .testDataGenerator: return .indigo
        case .localMemo: return .yellow
        case .windowManager: return .cyan
        case .systemMonitor: return .green
        case .pomodoroTimer, .timerBoard, .meetingTimer, .timeCalculator: return .orange
        case .personalCalendar, .businessDays: return Color(red: 0.02, green: 0.65, blue: 0.47)
        case .audioCheck: return Color(red: 0.0, green: 0.62, blue: 0.87)
        case .microphoneCheck: return .purple
        case .csvViewer: return .blue
        case .csvEditor: return .orange
        case .sequentialText: return .indigo
        case .clipboardFormatter: return .teal
        case .textCleaner: return .pink
        case .lineTools: return Color(red: 0.77, green: 0.48, blue: 0.09)
        case .stringReplacer: return Color(red: 0.89, green: 0.23, blue: 0.27)
        case .textCodec: return .cyan
        case .imageResizer: return .orange
        case .userAgent: return .cyan
        case .colorPalette: return .pink
        case .comparison: return Color(red: 0.23, green: 0.43, blue: 0.94)
        }
    }
}

private extension UTType {
    static let myToolBoxFavorite = UTType(exportedAs: "local.MyToolBox.favorite", conformingTo: .data)
}

private struct FavoriteDropDelegate: DropDelegate {
    let target: String
    @Binding var raw: String
    @Binding var dragged: String?
    @Binding var highlighted: String?
    func validateDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: [.myToolBoxFavorite]), let dragged, dragged != target else { return false }
        let favorites = ToolFavorites.decode(raw)
        return favorites.contains(dragged) && favorites.contains(target)
    }
    func dropEntered(info: DropInfo) { if validateDrop(info: info) { highlighted = target } }
    func dropExited(info: DropInfo) { if highlighted == target { highlighted = nil } }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: validateDrop(info: info) ? .move : .cancel) }
    func performDrop(info: DropInfo) -> Bool {
        guard validateDrop(info: info), let source = dragged else { return false }
        raw = ToolFavorites.moving(source, to: target, in: raw)
        dragged = nil; highlighted = nil
        return true
    }
}
