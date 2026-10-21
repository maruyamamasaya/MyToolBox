import SwiftUI
import AVFoundation
import CoreAudio
import AudioToolbox

struct AudioDevice: Identifiable {
    let id: AudioDeviceID
    let name: String
    static func devices(input: Bool) -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: input ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr, streamSize > 0 else { return nil }
            var nameAddress = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var name: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &name) == noErr else { return nil }
            guard let name else { return nil }
            return AudioDevice(id: id, name: name.takeRetainedValue() as String)
        }
    }
}

/// Only this engine's route changes. Never sets the system default device.
private func route(_ node: AVAudioIONode, to device: AudioDeviceID) throws {
    guard device != 0 else { return }
    guard let unit = node.audioUnit else { throw ToolFailure.message("オーディオ装置を初期化できません") }
    var id = device
    let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id, UInt32(MemoryLayout.size(ofValue: id)))
    guard status == noErr else { throw ToolFailure.message("装置を選択できません（OSStatus \(status)）") }
}

@MainActor final class SpeakerModel: ObservableObject {
    @Published var devices = AudioDevice.devices(input: false)
    @Published var device: AudioDeviceID = 0
    @Published var volume: Double = 0.15
    @Published var status = "音量を低めにして、テストボタンを押してください"
    @Published var playing = false
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var generation = UUID()
    func stop() { generation = UUID(); player?.stop(); engine?.stop(); player = nil; engine = nil; playing = false }
    func play(channel: Int) {
        stop()
        do {
            let engine = AVAudioEngine(); let player = AVAudioPlayerNode()
            try route(engine.outputNode, to: device)
            let output = engine.outputNode.outputFormat(forBus: 0)
            guard output.channelCount >= 2, output.sampleRate > 0 else { throw ToolFailure.message("ステレオ出力を利用できません。出力装置を確認してください") }
            let rate = output.sampleRate
            guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return }
            let seconds = channel == 2 ? 2.4 : 0.6
            let frames = Int(rate * seconds)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)), let data = buffer.floatChannelData else { return }
            buffer.frameLength = AVAudioFrameCount(frames)
            for i in 0..<frames {
                let values = AudioSignal.stereo(time: Double(i) / rate, sequence: channel, volume: volume)
                data[0][i] = values.0; data[1][i] = values.1
            }
            engine.attach(player); engine.connect(player, to: engine.mainMixerNode, format: format)
            self.engine = engine; self.player = player
            try engine.start(); playing = true
            status = "再生中 · 440 Hz · \(Int(rate)) Hz · " + (channel == 2 ? "左 → 右 → 両方" : channel == 0 ? "左" : "右")
            let token = generation
            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor in guard let self, self.generation == token else { return }; self.stop(); self.status = "再生終了。左右と音の聞こえ方を確認してください" }
            }
            player.play()
        } catch { stop(); status = error.localizedDescription }
    }
}

/// Tap callback shares only this bounded buffer, never SwiftUI state.
private final class MicSamples: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []
    private var recording = false
    private var rms: Float = 0
    private var peak: Float = 0
    private var limit = 0
    func begin(rate: Double) { lock.lock(); defer { lock.unlock() }; samples = []; limit = Int(rate * 10); samples.reserveCapacity(limit); recording = true }
    func consume(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return }
        let count = Int(buffer.frameLength)
        let values = AudioSignal.levels(UnsafeBufferPointer(start: data[0], count: count))
        lock.lock(); defer { lock.unlock() }
        rms = values.rms; peak = values.peak
        if recording { samples.append(contentsOf: UnsafeBufferPointer(start: data[0], count: min(count, max(0, limit - samples.count)))) }
    }
    func levels() -> (Float, Float) { lock.lock(); defer { lock.unlock() }; return (rms, peak) }
    func finish() -> [Float] { lock.lock(); defer { lock.unlock() }; recording = false; return samples }
    func clear() { lock.lock(); defer { lock.unlock() }; samples = []; recording = false; rms = 0; peak = 0 }
}

@MainActor final class MicrophoneModel: ObservableObject {
    @Published var devices = AudioDevice.devices(input: true)
    @Published var device: AudioDeviceID = 0
    @Published var status = "開始ボタンでマイク使用を許可します"
    @Published var running = false
    @Published var pending = false
    @Published var recording = false
    @Published var level: Double = 0
    @Published var decibels = "—"
    @Published var elapsed: Double = 0
    @Published var hasRecording = false
    private var engine: AVAudioEngine?
    private var playback: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var timer: Timer?
    private var started: TimeInterval = 0
    private var rate: Double = 0
    private var audio: [Float] = []
    private let capture = MicSamples()
    private var generation = UUID()
    func start() {
        stop(clear: true); pending = true
        let token = generation
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.pending = false
                guard granted else { self.status = "マイクへのアクセスが拒否されました。システム設定のプライバシーとセキュリティで確認してください"; return }
                self.beginCapture()
            }
        }
    }
    private func beginCapture() {
        do {
            let engine = AVAudioEngine(); let input = engine.inputNode
            try route(input, to: device)
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.sampleRate <= 384_000, format.channelCount > 0, format.commonFormat == .pcmFormatFloat32 else { throw ToolFailure.message("対応するマイク入力を利用できません") }
            rate = format.sampleRate; let capture = capture
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in capture.consume(buffer) }
            self.engine = engine; try engine.start(); running = true
            status = "入力中 · \(Int(rate)) Hz · 先頭チャンネル（再生への返送なし）"
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        } catch { stop(clear: true); status = error.localizedDescription }
    }
    private func tick() {
        let values = capture.levels(); level = Double(values.0)
        decibels = values.0 > 0 ? String(format: "%.1f dBFS", 20 * log10(values.0)) : "−∞ dBFS"
        if values.1 >= 0.99 { status = "入力がクリップしています。入力音量を下げてください" }
        if recording { elapsed = min(10, ProcessInfo.processInfo.systemUptime - started); if elapsed >= 10 { finishRecording() } }
        if let engine, !engine.isRunning { stop(clear: false); status = "入力装置が停止しました。装置を確認して再開してください" }
    }
    func record() {
        guard running else { return }
        audio = []; hasRecording = false; elapsed = 0
        capture.begin(rate: rate); started = ProcessInfo.processInfo.systemUptime; recording = true
    }
    func finishRecording() {
        guard recording else { return }
        audio = capture.finish(); recording = false; stop(clear: false); hasRecording = !audio.isEmpty
        status = hasRecording ? "録音完了 · マイク停止 · \(String(format: "%.1f", Double(audio.count) / rate)) 秒" : "録音データがありません"
    }
    func stop(clear: Bool = false) {
        generation = UUID(); pending = false; timer?.invalidate(); timer = nil
        engine?.inputNode.removeTap(onBus: 0); engine?.stop(); engine = nil
        player?.stop(); playback?.stop(); player = nil; playback = nil
        running = false; recording = false; level = 0; decibels = "—"; capture.clear()
        if clear { audio = []; hasRecording = false; elapsed = 0 }
    }
    func play() {
        guard !audio.isEmpty, rate > 0 else { return }
        stop(clear: false)
        do {
            let engine = AVAudioEngine(); let player = AVAudioPlayerNode()
            guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.count)), let data = buffer.floatChannelData else { throw ToolFailure.message("再生バッファを作成できません") }
            buffer.frameLength = AVAudioFrameCount(audio.count)
            audio.withUnsafeBufferPointer { pointer in data[0].update(from: pointer.baseAddress!, count: pointer.count) }
            engine.attach(player); engine.connect(player, to: engine.mainMixerNode, format: format)
            playback = engine; self.player = player; try engine.start()
            let token = generation
            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in Task { @MainActor in guard let self, self.generation == token else { return }; self.stop(); self.status = "録音の再生終了" } }
            player.play(); status = "録音を再生中（システムの出力装置）"
        } catch { stop(); status = error.localizedDescription }
    }
}

struct AudioCheckView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var model: SpeakerModel
    @State private var expanded: Bool
    @State private var showsHelp = false
    init(model: SpeakerModel, initiallyExpanded: Bool = false) {
        self.model = model; _expanded = State(initialValue: initiallyExpanded)
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("オーディオチェック", systemImage: "headphones").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            HStack {
                Picker("出力", selection: $model.device) {
                    Text("システムの既定").tag(AudioDeviceID(0))
                    ForEach(model.devices) { Text($0.name).tag($0.id) }
                }
                Button { model.stop(); model.devices = AudioDevice.devices(input: false); model.device = 0 } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 24, height: 24).contentShape(Rectangle())
                }.accessibilityLabel("出力デバイス一覧を更新")
            }
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        channelButton("左", "l.circle", channel: 0)
                        channelButton("右", "r.circle", channel: 1)
                        channelButton("ステレオ", "hifispeaker.2", channel: 2)
                    }
                    Text("ステレオ：左 → 右 → 両方").font(.caption).foregroundStyle(.secondary)
                    VStack(spacing: 10) {
                        HStack {
                            Label("テスト音量", systemImage: "speaker.wave.1").font(.caption)
                            Spacer(); Text("\(Int(model.volume * 100))%").font(.system(.title3, design: .rounded).bold()).monospacedDigit()
                        }
                        Slider(value: $model.volume, in: 0.05...0.6).accessibilityLabel("テスト音量")
                        HStack { Text("小さな音量からお試しください"); Spacer(); Text("440 Hz") }.font(.caption2).foregroundStyle(.secondary)
                    }.padding(10).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 8))
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(model.playing ? Color.cyan : Color.secondary.opacity(0.4)).frame(width: 7, height: 7).padding(.top, 4)
                        Text(model.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(2)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack {
                Button { model.stop(); model.status = "停止しました" } label: { Label("停止", systemImage: "stop.fill").frame(minWidth: 70, minHeight: 24) }.disabled(!model.playing)
                Spacer()
                Button { showsHelp.toggle() } label: { Image(systemName: "questionmark.circle").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("オーディオチェックの説明").popover(isPresented: $showsHelp) {
                        Text("440Hzの音をアプリ内で生成し、フェードを付けて再生します。システムの出力先と音量は変更しません。テスト音量は5〜60%です。デバイスを接続し直した場合は一覧を更新してください。")
                            .font(.caption).padding(16).frame(width: 310)
                    }
            }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 420, height: 400)))
            .frame(minWidth: expanded ? 800 : 400, idealWidth: expanded ? 1100 : 420,
                   minHeight: expanded ? 600 : 380, idealHeight: expanded ? 850 : 400)
            .onChange(of: model.device) { _, _ in model.stop() }
    }
    private func channelButton(_ title: String, _ symbol: String, channel: Int) -> some View {
        Button { model.play(channel: channel) } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: expanded ? 44 : 24))
                Text(title).font(.headline)
            }.frame(maxWidth: .infinity, minHeight: expanded ? 160 : 70).contentShape(Rectangle())
        }.accessibilityLabel(title + "をテスト再生")
    }
}

struct MicrophoneCheckView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var model: MicrophoneModel
    private var meterValue: Double { model.level > 0 ? max(0, min(1, (20 * log10(model.level) + 60) / 60)) : 0 }
    @State private var expanded: Bool
    @State private var showsHelp = false
    init(model: MicrophoneModel, initiallyExpanded: Bool = false) {
        self.model = model; _expanded = State(initialValue: initiallyExpanded)
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("マイクチェック", systemImage: "mic").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            HStack {
                Picker("入力", selection: $model.device) {
                    Text("システムの既定").tag(AudioDeviceID(0))
                    ForEach(model.devices) { Text($0.name).tag($0.id) }
                }.disabled(model.running || model.pending)
                Button { model.stop(clear: true); model.devices = AudioDevice.devices(input: true); model.device = 0 } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 24, height: 24).contentShape(Rectangle())
                }.accessibilityLabel("入力デバイス一覧を更新").help("一覧を更新して録音を破棄")
            }
            ScrollView {
                VStack(spacing: 10) {
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Circle().fill(model.running ? Color.green : Color.secondary).frame(width: 6, height: 6)
                            Text(model.running ? "マイク入力中" : "マイク停止中").font(.caption).foregroundStyle(.secondary)
                        }
                        Text(model.decibels).font(.system(size: expanded ? 64 : 32, weight: .medium, design: .rounded)).monospacedDigit().contentTransition(.numericText())
                        HStack(spacing: expanded ? 5 : 3) {
                            ForEach(0..<40) { index in
                                RoundedRectangle(cornerRadius: theme.classic ? 0 : 2)
                                    .fill(Double(index) / 40 < meterValue ? (index > 35 ? Color.red : index > 29 ? Color.yellow : Color.mint) : Color.primary.opacity(0.07))
                                    .frame(height: expanded ? 64 : 22)
                            }
                        }.accessibilityLabel("入力レベル").accessibilityValue(model.decibels)
                        HStack { Text("−60"); Spacer(); Text("−30"); Spacer(); Text("0 dBFS") }.font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                        HStack {
                            Button { model.start() } label: { Label(model.pending ? "許可確認中…" : "マイクを開始", systemImage: "mic.fill").frame(maxWidth: .infinity, minHeight: 24) }
                                .disabled(model.running || model.pending)
                            Button {
                                if model.recording { model.finishRecording() } else { model.stop(); model.status = "停止しました" }
                            } label: { Label("停止", systemImage: "stop.fill").frame(maxWidth: .infinity, minHeight: 24) }
                                .disabled(!model.running && !model.pending && !model.hasRecording)
                        }
                    }.padding(10).frame(maxWidth: .infinity).background(Color.purple.opacity(0.06), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 10))
                    VStack(spacing: 8) {
                        HStack {
                            Label("録音して聞き返す", systemImage: "waveform").font(.caption)
                            Spacer()
                            Text(String(format: "%.1f / 10秒", model.elapsed)).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        ProgressView(value: model.elapsed, total: 10).tint(model.recording ? .red : .purple)
                        HStack {
                            Button { model.recording ? model.finishRecording() : model.record() } label: {
                                Label(model.recording ? "録音を終了" : "10秒録音", systemImage: model.recording ? "stop.circle.fill" : "record.circle")
                                    .foregroundStyle(model.recording ? .red : .primary).frame(maxWidth: .infinity, minHeight: 24)
                            }.disabled(!model.running)
                            Button { model.play() } label: { Label("録音を再生", systemImage: "play.fill").frame(maxWidth: .infinity, minHeight: 24) }
                                .disabled(!model.hasRecording || model.running)
                        }
                    }.padding(10).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 10))
                    Text(model.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(2)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack {
                Text("最大10秒・メモリ内のみ").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { showsHelp.toggle() } label: { Image(systemName: "questionmark.circle").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("マイクチェックの説明").popover(isPresented: $showsHelp) {
                        Text("入力レベルはデジタル信号のRMS（dBFS）で、周囲の音圧ではありません。開始操作でマイク許可を確認します。録音後はマイクを停止。画面を閉じると録音を破棄し、保存・外部送信は行いません。再生はシステムの出力装置を使います。デバイス一覧の更新は録音を破棄します。")
                            .font(.caption).padding(16).frame(width: 310)
                    }
            }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 400, height: 500)))
            .frame(minWidth: expanded ? 800 : 380, idealWidth: expanded ? 1100 : 400,
                   minHeight: expanded ? 600 : 460, idealHeight: expanded ? 850 : 500)
    }
}
