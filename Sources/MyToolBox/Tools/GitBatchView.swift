import SwiftUI

@MainActor final class GitBatchModel: ObservableObject {
    @Published var root: String
    @Published var rows: [GitRepositoryStatus] = []
    @Published var selected: Set<String> = []
    @Published var message = "Work sync \(Date().formatted(date: .numeric, time: .shortened))"
    @Published var busy = false
    @Published var status = "フォルダを選び、ローカル状態を読み込んでください。"
    private let worker = GitBatchWorker()
    private let defaults: UserDefaults
    private var loadedRoot: String?
    init(defaults: UserDefaults = IndependentTools.defaults) {
        self.defaults = defaults
        root = defaults.string(forKey: "tools.gitBatch.root") ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Development").path
    }
    var canClose: Bool { !busy }
    func choose() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.directoryURL = URL(fileURLWithPath: root)
        if panel.runModal() == .OK, let url = panel.url { root = url.path; rows = []; selected = []; load() }
    }
    func load() {
        guard !busy else { return }
        let previousSelection = loadedRoot == root ? selected : []
        busy = true; rows = []; selected = []; status = "ローカル状態を確認中…"
        let folder = root
        Task {
            do {
                let paths = try await worker.discover(root: folder)
                rows = await worker.run(paths: paths, action: .inspect, message: "")
                selected = previousSelection.intersection(Set(paths))
                loadedRoot = folder
                defaults.set(folder, forKey: "tools.gitBatch.root")
                status = paths.isEmpty ? "直下にGitリポジトリがありません。" : "\(paths.count)件を読み込みました。チェックした対象だけを取得・更新できます。"
            } catch { status = error.localizedDescription }
            busy = false
        }
    }
    func run(_ action: GitBatchAction, decide: (() -> Bool)? = nil) {
        guard !busy else { return }
        let targets = rows.filter { selected.contains($0.path) }
        guard !targets.isEmpty else { return }
        if action == .finish || action == .start {
            if let decide {
                guard decide() else { return }
            } else {
                let alert = NSAlert()
                alert.messageText = action == .finish ? "選択した\(targets.count)件をコミット・送信しますか？" : "選択した\(targets.count)件を更新しますか？"
                alert.informativeText = targets.map(\.name).joined(separator: "\n") + (action == .finish ? "\n\n未追跡・削除を含む全変更をステージし、入力したメッセージでコミットしてoriginの同名ブランチへ送信します。\n\n\(message)" : "\n\noriginを取得し、未コミット変更・未送信がないリポジトリだけ早送り更新します。")
                alert.addButton(withTitle: "実行"); alert.addButton(withTitle: "キャンセル")
                guard alert.runModal() == .alertFirstButtonReturn else { return }
            }
        }
        busy = true; status = "\(targets.count)件を処理中…（各Git操作は最大120秒）"
        let commitMessage = message
        Task {
            for target in targets {
                status = "\(target.name) を処理中…"
                let results = await worker.run(paths: [target.path], action: action, message: commitMessage)
                if let result = results.first, let index = rows.firstIndex(where: { $0.path == result.path }) { rows[index] = result }
            }
            let targetPaths = Set(targets.map(\.path))
            let good = rows.filter { targetPaths.contains($0.path) && $0.succeeded }.count
            status = "完了：一致・同期済み \(good)件 ／ 差分・要確認 \(targets.count - good)件"
            busy = false
        }
    }
}
struct GitBatchView: View {
    @ObservedObject var model: GitBatchModel
    @State private var expanded: Bool
    init(model: GitBatchModel, initiallyExpanded: Bool = false) {
        self.model = model; _expanded = State(initialValue: initiallyExpanded)
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Git一括管理", systemImage: "arrow.triangle.branch").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(model.root).font(.caption).textSelection(.enabled).lineLimit(1).truncationMode(.middle).help(model.root)
                            Spacer()
                            Button { model.choose() } label: { Image(systemName: "folder").frame(width: 24, height: 24) }.accessibilityLabel("フォルダを選択")
                            Button { model.load() } label: { Image(systemName: "arrow.clockwise").frame(width: 24, height: 24) }.accessibilityLabel("ローカル読込")
                        }
                        HStack {
                            Button("全選択") { model.selected = Set(model.rows.map(\.path)) }
                            Button("選択解除") { model.selected = [] }
                            Text("\(model.selected.count) / \(model.rows.count)件を選択").foregroundStyle(.secondary)
                        }
                        TextField("コミットメッセージ", text: $model.message).textFieldStyle(.roundedBorder)
                        HStack(spacing: 6) {
                            Button("状態確認（通信）") { model.run(.check) }
                            Button("選択分を更新…") { model.run(.start) }
                            Button("コミット・送信…") { model.run(.finish) }.disabled(model.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }.disabled(model.selected.isEmpty)
                    }
                }.disabled(model.busy)
                Text("チェックしたリポジトリだけが通信・更新・送信の対象です。").font(.caption).foregroundStyle(.secondary)
                HStack { if model.busy { ProgressView().controlSize(.small) }; Text(model.status).font(.caption) }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.rows) { row in
                            Group {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Toggle(row.name, isOn: Binding(get: { model.selected.contains(row.path) }, set: { if $0 { model.selected.insert(row.path) } else { model.selected.remove(row.path) } })).toggleStyle(.checkbox).font(.headline).disabled(model.busy)
                                        Spacer()
                                        Text(row.result).foregroundStyle(row.succeeded ? Color.green : Color.orange)
                                    }
                                    Text("\(row.branch.isEmpty ? "ブランチ不明" : row.branch) · 未送信 \(row.ahead.map(String.init) ?? "—") · 未取得 \(row.behind.map(String.init) ?? "—")").font(.callout)
                                    Text(row.checkedAt.formatted(date: .omitted, time: .standard)).font(.caption).foregroundStyle(.secondary)
                                    if !row.changes.isEmpty {
                                        DisclosureGroup("変更ファイル（全変更がコミット対象）") { Text(row.changes).font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                                    }
                                    Text(row.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                }.padding(8).frame(maxWidth: .infinity, alignment: .leading).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
                ToolFootnote(text: "通信は明示操作時のみ。認証は既存のGit・SSH設定を使用します。競合の自動解消・強制送信は行いません。処理中は画面を閉じられません。")
            }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 480, height: 600)))
            .frame(minWidth: expanded ? 800 : 460, idealWidth: expanded ? 1100 : 480, minHeight: expanded ? 600 : 520, idealHeight: expanded ? 850 : 600)
    }
}
