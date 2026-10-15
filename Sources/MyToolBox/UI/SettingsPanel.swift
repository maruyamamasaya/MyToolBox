import SwiftUI
import ServiceManagement
struct SettingsPanel: View {
    @ObservedObject var store: MonitorStore
    var body: some View {
        Form {
            Section("表示と取得") {
                Picker("更新間隔", selection: $store.preferences.interval) { Text("1秒").tag(1.0); Text("2秒").tag(2.0); Text("5秒").tag(5.0) }
                Toggle("コンパクトなメニューバー表示", isOn: $store.preferences.compact)
                Toggle("詳細の容量・通信速度を2進単位（KiB, MiB）にする", isOn: $store.preferences.binaryUnits)
                Text("メニューの通信速度はKB/s・MB/s、SSDはGBで表示します。").font(.caption)
                Toggle("温度を華氏（°F）にする", isOn: $store.preferences.fahrenheit)
                TextField("ネットワークIF（auto = 主経路）", text: $store.preferences.interface)
                Text("利用可能なIFと接続状態はNetwork詳細に表示します。温度・ファンは5秒周期で取得します。").font(.caption)
            }
            Section("メニューバーの表示／順序") {
                ForEach(store.preferences.order, id: \.self) { id in
                    HStack {
                        Toggle(id == "sensors" ? "温度・ファン（数値）" : id.capitalized, isOn: Binding(get: { !store.preferences.hidden.contains(id) }, set: { enabled in
                            if enabled { store.preferences.hidden.remove(id) } else { store.preferences.hidden.insert(id) }
                        }))
                        Spacer()
                        Button { store.move(id, by: -1) } label: { Image(systemName: "arrow.up") }.disabled(store.preferences.order.first == id).accessibilityLabel("\(id)を上へ")
                        Button { store.move(id, by: 1) } label: { Image(systemName: "arrow.down") }.disabled(store.preferences.order.last == id).accessibilityLabel("\(id)を下へ")
                    }
                }
            }
            Section("定期ログ（このMac内のみ）") {
                Toggle("監視ログを保存", isOn: $store.logPreferences.enabled)
                Picker("記録間隔", selection: $store.logPreferences.interval) {
                    Text("1秒").tag(1.0); Text("10秒").tag(10.0); Text("60秒").tag(60.0)
                }
                Picker("保存期間", selection: $store.logPreferences.retentionDays) {
                    Text("24時間").tag(1); Text("7日間").tag(7); Text("30日間").tag(30)
                }
                if let date = store.lastLogDate { Text("最終保存：") + Text(date, style: .time) }
                if let error = store.logError { Text("ログ保存失敗：" + error).foregroundStyle(.red).textSelection(.enabled) }
                Button("ログフォルダを開く") {
                    do {
                        try FileManager.default.createDirectory(at: MonitoringLog.directory, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(MonitoringLog.directory)
                    } catch { store.logError = error.localizedDescription }
                }
                Text("JSONL形式。各時点の値を保存し、平均値ではありません。記録間隔は画面の取得間隔以上になります。スリープ中は記録せず、古い日別ログは自動整理します。1日32MiBまで。").font(.caption)
            }
            Section("ログイン起動") {
                Text("状態：\(store.loginStatus)")
                HStack {
                    Button("有効にする") { store.setLogin(true) }
                    Button("無効にする") { store.setLogin(false) }
                    Button("状態を更新") { store.refreshLoginStatus() }
                }
                if store.loginStatus == "システム設定で承認待ち" { Button("ログイン項目の設定を開く") { SMAppService.openSystemSettingsLoginItems() } }
                if let error = store.loginError { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                Text("明示的にボタンを押した場合だけ登録を変更します。安定した場所に.appを置いてから設定してください。").font(.caption)
            }
        }.formStyle(.grouped).padding()
    }
}
