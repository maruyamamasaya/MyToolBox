import SwiftUI
import WebKit

@MainActor final class UserAgentModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var fields: [(String, String)] = []
    @Published var userAgent = ""
    @Published var status = "取得中…"
    @Published var busy = true
    let webView: WKWebView
    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.loadHTMLString("<!doctype html><meta name='viewport' content='width=device-width'><title>Local device probe</title>", baseURL: nil)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { refresh() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
    private func fail(_ error: Error) { busy = false; fields = []; userAgent = ""; status = "取得失敗: " + error.localizedDescription }
    func refresh() {
        busy = true; fields = []; userAgent = ""; status = "取得中…"
        webView.evaluateJavaScript(Self.script) { [weak self] value, error in
            guard let self else { return }
            if let error { self.fail(error); return }
            guard let values = value as? [String: String], let ua = values["ua"] else {
                self.fail(NSError(domain: "UserAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "取得結果を読み取れませんでした"])); return
            }
            self.userAgent = ua
            let info = UserAgentInfo(ua)
            self.fields = [("ブラウザ環境", "MyToolBox 内蔵WebKit"), ("UAのブラウザ表記", info.browser),
                           ("UAのOS表記", info.os), ("実行中のOS", ProcessInfo.processInfo.operatingSystemVersionString),
                           ("デバイス種別（UA判定）", info.device)]
                + [("screen", "画面解像度（CSS px）"), ("viewport", "内蔵WebKitのViewport（CSS px）"),
                   ("ratio", "Device Pixel Ratio"), ("language", "言語"), ("timezone", "タイムゾーン"),
                   ("cookie", "Cookie対応"), ("online", "接続状態（navigator.onLine）"),
                   ("cpu", "CPU論理コア数（WebKit公開値）"), ("memory", "メモリ容量（WebKit公開値）"),
                   ("touch", "最大タッチ点数")].map { ($0.1, values[$0.0] ?? "取得不可") }
            self.busy = false; self.status = "更新しました"
        }
    }
    var report: String { (["User-Agent Viewer", "取得元: MyToolBox 内蔵WebKit"] + fields.map { $0.0 + ": " + $0.1 } + ["User-Agent: " + userAgent]).joined(separator: "\n") }
    static let script = """
    (() => {
      const n = navigator, missing = '取得不可';
      return {ua:n.userAgent, screen:`${screen.width} × ${screen.height}`,
        viewport:`${innerWidth} × ${innerHeight}`, ratio:String(devicePixelRatio),
        language:n.language || missing, timezone:Intl.DateTimeFormat().resolvedOptions().timeZone || missing,
        cookie:typeof n.cookieEnabled === 'boolean' ? (n.cookieEnabled ? '有効' : '無効') : missing,
        online:typeof n.onLine === 'boolean' ? (n.onLine ? 'Online' : 'Offline') : missing,
        cpu:n.hardwareConcurrency ? String(n.hardwareConcurrency) + ' コア' : missing,
        memory:n.deviceMemory ? String(n.deviceMemory) + ' GB' : missing,
        touch:typeof n.maxTouchPoints === 'number' ? String(n.maxTouchPoints) : missing};
    })()
    """
}
private struct UserAgentProbe: NSViewRepresentable {
    let model: UserAgentModel
    func makeNSView(context: Context) -> WKWebView { model.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
struct UserAgentView: View {
    @StateObject private var model = UserAgentModel()
    @State private var pasted = ""
    @State private var inspect = false
    @State private var copyStatus = ""
    var body: some View {
        ToolPage("User-Agent Viewer", subtitle: "ブラウザ環境・端末情報を確認してコピー。", symbol: "desktopcomputer", tint: .cyan) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Toggle("別のUser-Agentを調べる", isOn: $inspect)
                    if inspect {
                        TextEditor(text: $pasted).font(.system(.body, design: .monospaced)).frame(height: 100)
                        Button("貼り付け") { pasted = NSPasteboard.general.string(forType: .string) ?? "" }
                        if pasted.utf8.count > 65536 { Text("入力は64KiB以内にしてください").foregroundStyle(.red) }
                        else {
                            let info = UserAgentInfo(pasted)
                            ToolCard { VStack(alignment: .leading, spacing: 10) { Text(info.browser); Text(info.os); Text(info.device) } }
                            Button("解析結果をコピー") { copy("ブラウザ: \(info.browser)\nOS: \(info.os)\nデバイス種別: \(info.device)\nUser-Agent: \(pasted)") }.disabled(pasted.isEmpty)
                        }
                        ToolFootnote(text: "貼り付けたUA文字列のみから推定します。画面・言語・接続状態などはUAから取得できません。iPadのデスクトップ用UAや偽装UAは正しく判定できない場合があります。")
                    } else {
                        HStack { Button("更新") { model.refresh() }.disabled(model.busy); if model.busy { ProgressView().controlSize(.small) }; Text(model.status).font(.caption); Spacer(); Button("すべてコピー") { copy(model.report) }.disabled(model.busy || model.userAgent.isEmpty) }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                            ForEach(model.fields.indices, id: \.self) { index in
                                ToolCard { VStack(alignment: .leading, spacing: 8) { Text(model.fields[index].0).font(.caption).foregroundStyle(.secondary); Text(model.fields[index].1).textSelection(.enabled) } }
                            }
                        }
                        ToolCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack { Text("User-Agent").font(.headline); Spacer(); Button("UAをコピー") { copy(model.userAgent) }.disabled(model.busy || model.userAgent.isEmpty) }
                                Text(model.userAgent).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            }
                        }
                        ToolFootnote(text: "内蔵WebKitの取得値です。Safari・Chrome等の情報ではありません。UAのOS表記は互換性のため実際のOSと異なる場合があります。Onlineはインターネット疎通を保証しません。取得できない値は「取得不可」と表示します。リサイズ後は更新してください。")
                    }
                    Text(copyStatus).font(.caption).foregroundStyle(.secondary)
                    ToolFootnote(text: "端末内だけで処理。情報の外部送信・自動保存は行いません。")
                }.padding(24)
            }
        }.background { UserAgentProbe(model: model).opacity(0).allowsHitTesting(false).accessibilityHidden(true) }
            .frame(minWidth: 880, minHeight: 760)
    }
    private func copy(_ text: String) { NSPasteboard.general.clearContents(); copyStatus = NSPasteboard.general.setString(text, forType: .string) ? "コピーしました" : "コピーできませんでした" }
}
