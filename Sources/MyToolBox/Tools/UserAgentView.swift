import SwiftUI
import WebKit

@MainActor final class UserAgentModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var fields: [(String, String)] = []
    @Published var userAgent = ""
    @Published var status = "取得中…"
    @Published var busy = true
    let webView: WKWebView
    init(automaticallyLoads: Bool = true) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        if automaticallyLoads { webView.loadHTMLString("<!doctype html><meta name='viewport' content='width=device-width'><title>Local device probe</title>", baseURL: nil) }
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
    @Environment(\.appTheme) private var theme
    @StateObject private var model: UserAgentModel
    @State private var pasted: String
    @State private var tab: Int
    @State private var copyStatus = ""
    init(model: UserAgentModel? = nil, initialTab: Int = 0, initialPasted: String = "") {
        _model = StateObject(wrappedValue: model ?? UserAgentModel())
        _tab = State(initialValue: initialTab); _pasted = State(initialValue: initialPasted)
    }
    private var localInfo: UserAgentInfo { UserAgentInfo(model.userAgent) }
    private var runtimeOS: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }
    private var canCopyLocal: Bool { !model.busy && !model.userAgent.isEmpty }
    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("User-Agent Viewer").font(theme.font(22, weight: .bold, design: .rounded))
                    Text("端末の情報を、見やすく。").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                ThemeMenu()
            }
            Picker("表示", selection: $tab) {
                Text("この端末").tag(0); Text("詳しい情報").tag(1); Text("別のUAを解析").tag(2)
            }.pickerStyle(.segmented).labelsHidden()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if tab == 2 { externalAnalysis }
                    else if tab == 1 { details }
                    else { overview }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                if tab != 2 {
                    Button { model.refresh() } label: { Label("更新", systemImage: "arrow.clockwise").frame(minHeight: 28) }
                        .disabled(model.busy)
                    Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer(minLength: 0)
                    Button { copy(model.report) } label: { Text("全情報をコピー").frame(minHeight: 28) }.disabled(!canCopyLocal)
                } else {
                    Text("貼り付けたUA文字列から推定").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
            }
            if !copyStatus.isEmpty { Text(copyStatus).font(.caption).foregroundStyle(.secondary) }
        }.padding(16).controlSize(.regular)
            .frame(minWidth: 460, idealWidth: 520, minHeight: 580, idealHeight: 640)
            .background { UserAgentProbe(model: model).opacity(0).allowsHitTesting(false).accessibilityHidden(true) }
            .onChange(of: pasted) { _, _ in copyStatus = "" }
            .onChange(of: tab) { _, _ in copyStatus = "" }
            .onChange(of: model.userAgent) { _, _ in copyStatus = "" }
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("取得元：MyToolBox 内蔵WebKit").font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                summaryRow("ブラウザ", value: "内蔵WebKit", detail: model.userAgent.isEmpty ? "UAは" + (model.busy ? "取得中" : "取得不可") : "UAの表記：" + localInfo.browser, symbol: "globe", color: .cyan)
                Divider().opacity(0.4)
                summaryRow("OS", value: runtimeOS, detail: model.userAgent.isEmpty ? "実行中のOS" : "UAの表記：" + localInfo.os, symbol: "desktopcomputer", color: .purple)
                Divider().opacity(0.4)
                summaryRow("端末", value: model.userAgent.isEmpty ? (model.busy ? "取得中…" : "取得不可") : deviceName(localInfo.device), detail: "User-Agentから推定", symbol: "laptopcomputer", color: .orange)
            }.padding(12).background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius))
            uaPanel(model.userAgent, canCopy: canCopyLocal)
            Text("内蔵WebKitの情報を表示しています。UAのOS表記は互換性のため実際のOSと異なる場合があります。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func summaryRow(_ title: String, value: String, detail: String, symbol: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 21)).foregroundStyle(theme.classic ? theme.accent : color)
                .frame(width: 38, height: 38).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(theme.font(17, weight: .semibold)).textSelection(.enabled)
                Text(detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 9)
    }
    private func uaPanel(_ ua: String, canCopy: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("User-Agent 全文").font(.headline)
                Spacer()
                Button { copy(ua) } label: { Label("UAをコピー", systemImage: "doc.on.doc").frame(minHeight: 28) }.disabled(!canCopy)
            }
            ScrollView {
                Text(ua.isEmpty ? "取得したUAをここに表示します" : ua)
                    .font(.system(size: 13, design: .monospaced)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }.frame(height: 115).background(theme.panel, in: RoundedRectangle(cornerRadius: 8))
        }
    }
    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("内蔵WebKitから取得した情報").font(.headline)
            if model.fields.isEmpty {
                Text(model.status).foregroundStyle(.secondary)
            }
            ForEach(model.fields.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    Text(model.fields[index].0).font(.caption).foregroundStyle(.secondary).frame(width: 170, alignment: .leading)
                    Text(model.fields[index].1).font(.system(size: 13)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.vertical, 6)
                Divider().opacity(0.4)
            }
            Text("画面とViewportはCSS px。リサイズ後は更新してください。Onlineはインターネット疎通を保証しません。取得できない値は「取得不可」と表示します。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private var externalAnalysis: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("調べたいUser-Agent").font(.headline)
                Spacer()
                Button { pasted = NSPasteboard.general.string(forType: .string) ?? "" } label: {
                    Label("貼り付け", systemImage: "doc.on.clipboard").frame(minHeight: 28)
                }
            }
            TextEditor(text: $pasted).font(.system(size: 13, design: .monospaced))
                .frame(height: 120).accessibilityLabel("解析するUser-Agent")
            if pasted.utf8.count > 65536 {
                Text("入力は64KiB以内にしてください").foregroundStyle(.orange)
            } else if pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("UAを貼り付けると、ブラウザ・OS・端末種別を表示します。")
                    .foregroundStyle(.secondary)
            } else {
                let info = UserAgentInfo(pasted)
                VStack(spacing: 0) {
                    summaryRow("ブラウザ", value: info.browser, detail: "UAによる推定", symbol: "globe", color: .cyan)
                    Divider().opacity(0.4)
                    summaryRow("OS", value: info.os, detail: "UAによる表記", symbol: "desktopcomputer", color: .purple)
                    Divider().opacity(0.4)
                    summaryRow("端末", value: deviceName(info.device), detail: "UAによる推定", symbol: "iphone", color: .orange)
                }.padding(12).background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius))
                Button { copy("ブラウザ: \(info.browser)\nOS: \(info.os)\nデバイス種別: \(info.device)\nUser-Agent: \(pasted)") } label: {
                    Label("解析結果をコピー", systemImage: "doc.on.doc").frame(minHeight: 28)
                }
            }
            Text("画面・言語・接続状態はUAから取得できません。iPadのデスクトップ用UAや偽装UAは正確に判定できない場合があります。端末内だけで解析します。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func deviceName(_ value: String) -> String {
        switch value { case "Desktop": return "デスクトップ"; case "Mobile": return "モバイル"; case "Tablet": return "タブレット"; default: return value }
    }
    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        copyStatus = NSPasteboard.general.setString(text, forType: .string) ? "コピーしました" : "コピーできませんでした"
    }
}
