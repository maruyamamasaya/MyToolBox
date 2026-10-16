import SwiftUI

@MainActor final class GitBatchModel: ObservableObject {
    @Published var root = UserDefaults.standard.string(forKey: "tools.gitBatch.root") ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Development").path
    @Published var rows: [GitRepositoryStatus] = []
    @Published var selected: Set<String> = []
    @Published var message = "Work sync \(Date().formatted(date: .numeric, time: .shortened))"
    @Published var busy = false
    @Published var status = "フォルダを選び、ローカル状態を読み込んでください。"
    private let worker = GitBatchWorker()
    func choose() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.directoryURL = URL(fileURLWithPath: root)
        if panel.runModal() == .OK, let url = panel.url { root = url.path; rows = []; selected = []; load() }
    }
    func load() {
        guard !busy else { return }
        busy = true; rows = []; selected = []; status = "ローカル状態を確認中…"
        let folder = root
        Task {
            do {
                let paths = try await worker.discover(root: folder)
                rows = await worker.run(paths: paths, action: .inspect, message: "")
                selected = Set(paths)
                UserDefaults.standard.set(folder, forKey: "tools.gitBatch.root")
                status = paths.isEmpty ? "直下にGitリポジトリがありません。" : "\(paths.count)件を読み込みました。最新状態は「状態確認（通信）」で取得できます。"
            } catch { status = error.localizedDescription }
            busy = false
        }
    }
    func run(_ action: GitBatchAction) {
        guard !busy, !selected.isEmpty else { return }
        let targets = rows.filter { selected.contains($0.path) }
        if action == .finish || action == .start {
            let alert = NSAlert()
            alert.messageText = action == .finish ? "選択した\(targets.count)件をコミット・送信しますか？" : "選択した\(targets.count)件を更新しますか？"
            alert.informativeText = targets.map(\.name).joined(separator: "\n") + (action == .finish ? "\n\n未追跡・削除を含む全変更をステージし、入力したメッセージでコミットしてoriginの同名ブランチへ送信します。\n\n\(message)" : "\n\noriginを取得し、未コミット変更・未送信がないリポジトリだけ早送り更新します。")
            alert.addButton(withTitle: "実行"); alert.addButton(withTitle: "キャンセル")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        busy = true; status = "\(targets.count)件を処理中…（各Git操作は最大120秒）"
        let commitMessage = message
        Task {
            for target in targets {
                status = "\(target.name) を処理中…"
                let results = await worker.run(paths: [target.path], action: action, message: commitMessage)
                if let result = results.first, let index = rows.firstIndex(where: { $0.path == result.path }) { rows[index] = result }
            }
            let good = rows.filter { selected.contains($0.path) && $0.succeeded }.count
            status = "完了：一致・同期済み \(good)件 ／ 差分・要確認 \(targets.count - good)件"
            busy = false
        }
    }
}
struct GitBatchView: View {
    @ObservedObject var model: GitBatchModel
    var body: some View {
        ToolPage("Git一括管理", subtitle: "フォルダ直下のリポジトリを確認・更新・コミットして送信。", symbol: "arrow.triangle.branch", tint: .orange, usesNetwork: true) {
            VStack(alignment: .leading, spacing: 12) {
                ToolCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(model.root).textSelection(.enabled).lineLimit(2)
                            Spacer()
                            Button("フォルダを選択…") { model.choose() }
                            Button("ローカル読込") { model.load() }
                        }
                        HStack {
                            Button("全選択") { model.selected = Set(model.rows.map(\.path)) }
                            Button("選択解除") { model.selected = [] }
                            Text("\(model.selected.count) / \(model.rows.count)件を選択").foregroundStyle(.secondary)
                        }
                        TextField("コミットメッセージ", text: $model.message).textFieldStyle(.roundedBorder)
                        HStack {
                            Button("状態確認（通信）") { model.run(.check) }
                            Button("作業開始：取得・更新") { model.run(.start) }
                            Button("作業終了：コミット・送信…") { model.run(.finish) }.disabled(model.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }.disabled(model.selected.isEmpty)
                    }
                }.disabled(model.busy)
                HStack { if model.busy { ProgressView().controlSize(.small) }; Text(model.status).font(.callout) }
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.rows) { row in
                            ToolCard {
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
                                }
                            }
                        }
                    }
                }
                ToolFootnote(text: "通信は明示操作時のみ。認証は既存のGit・SSH設定を使用します。競合の自動解消・強制送信は行いません。処理中は画面を閉じられません。")
            }.padding(22)
        }.frame(minWidth: 820, minHeight: 650)
    }
}
