import SwiftUI
import Combine

@MainActor final class TimerBoardModel: ObservableObject {
    @Published var timers: [UtilityTimer] = []
    @Published var now = Date()
    @Published var message = ""
    private var ticker: AnyCancellable?
    private let defaults: UserDefaults
    private let key = "tools.timerBoard.v1"
    init(defaults: UserDefaults = IndependentTools.defaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode([UtilityTimer].self, from: data) {
            timers = Array(decoded.prefix(12)).filter { $0.duration.isFinite && $0.duration >= 0 && (!$0.countdown || $0.duration > 0) && $0.duration <= 359999 && $0.elapsed.isFinite && $0.elapsed >= 0 }
        }
        ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect().sink { [weak self] now in self?.tick(now) }
    }
    func save() { if let data = try? JSONEncoder().encode(timers) { defaults.set(data, forKey: key) } }
    func tick(_ date: Date) {
        now = date
        var changed = false
        for index in timers.indices where timers[index].startedAt != nil && timers[index].finished(at: now) {
            timers[index].elapsed = timers[index].duration; timers[index].startedAt = nil
            message = "\(timers[index].name) が終了しました"
            changed = true
        }
        if changed { save() }
    }
    func add() { guard timers.count < 12 else { return }; var timer = UtilityTimer(); timer.name = "タイマー \(timers.count + 1)"; timers.append(timer); save() }
    func toggle(_ index: Int) {
        if timers[index].startedAt != nil { timers[index].pause(at: Date()) }
        else { if timers[index].finished(at: Date()) { timers[index].reset() }; timers[index].start(at: Date()) }
        save()
    }
    func reset(_ index: Int) { timers[index].reset(); save() }
    func pauseAll() { for i in timers.indices { timers[i].pause(at: Date()) }; save() }
    func resetAll(finishedOnly: Bool) { for i in timers.indices where !finishedOnly || timers[i].finished(at: Date()) { timers[i].reset() }; message = ""; save() }
    func duplicate(_ index: Int) { guard timers.count < 12 else { return }; var copy = timers[index]; copy.id = UUID(); copy.name += " コピー"; copy.reset(); timers.insert(copy, at: index + 1); save() }
    func remove(_ index: Int) { timers.remove(at: index); save() }
    func move(_ index: Int, by offset: Int) { let target = index + offset; guard timers.indices.contains(target) else { return }; timers.swapAt(index, target); save() }
    func stop() { pauseAll(); ticker?.cancel(); ticker = nil }
}

struct TimerBoardView: View {
    @ObservedObject var model: TimerBoardModel
    @State private var showsSettings = false
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("タイマーボード").font(.headline)
                Text("\(model.timers.count)/12").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button { model.add() } label: { Image(systemName: "plus").frame(width: 28, height: 28).contentShape(Rectangle()) }
                    .accessibilityLabel("タイマーを追加").disabled(model.timers.count >= 12)
                Button { showsSettings = true } label: { Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle()) }
                    .accessibilityLabel("ボードの設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            Button("すべて一時停止") { model.pauseAll() }
                            Button("完了をリセット") { model.resetAll(finishedOnly: true) }
                            Button("すべてリセット") { model.resetAll(finishedOnly: false) }
                            ThemeMenu()
                            Text("設定と計測状態は自動保存。スリープ中も計測します。閉じると全一時停止。通知は画面内の色と点滅です。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            if !model.message.isEmpty {
                Text(model.message).font(.caption).foregroundStyle(.orange)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            ScrollView {
                VStack(spacing: 6) {
                    if model.timers.isEmpty {
                        Button("タイマーを追加", systemImage: "plus") { model.add() }
                            .buttonStyle(.borderedProminent).padding(.vertical, 32)
                    }
                    ForEach(Array(model.timers.enumerated()), id: \.element.id) { index, timer in
                        TimerBoardCard(model: model, index: index, timer: timer)
                    }
                }
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 300, idealWidth: 320, minHeight: 220, idealHeight: 280)
    }
}

private struct TimerBoardCard: View {
    @ObservedObject var model: TimerBoardModel
    let index: Int
    let timer: UtilityTimer
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsSettings = false
    private var finished: Bool { timer.finished(at: model.now) }
    private var warning: Bool { timer.countdown && timer.alerts && (timer.startedAt != nil || finished) && timer.remaining(at: model.now) <= Double(timer.warningSeconds) }
    private var time: String {
        let full = UtilityTimer.display(timer.countdown ? timer.remaining(at: model.now) : timer.elapsed(at: model.now))
        return full.hasPrefix("00:") ? String(full.dropFirst(3)) : full
    }
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text(timer.name).font(.caption.weight(.semibold)).lineLimit(1).help(timer.name)
                Spacer(minLength: 0)
                Text(finished ? "終了" : timer.startedAt != nil ? "計測中" : timer.elapsed > 0 ? "一時停止" : timer.countdown ? "準備完了" : "ストップウォッチ")
                    .font(.caption2).foregroundStyle(.secondary)
                Button { showsSettings = true } label: { Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle()) }
                    .accessibilityLabel(timer.name + "の設定")
                    .popover(isPresented: $showsSettings) { settings }
            }
            HStack(spacing: 8) {
                Text(time)
                    .font(.system(size: 25, weight: .medium, design: .monospaced))
                    .minimumScaleFactor(0.6).lineLimit(1)
                    .foregroundStyle(warning ? Color.orange : Color.primary)
                    .opacity(warning && !reduceMotion && Int(model.now.timeIntervalSince1970 * 2) % 2 == 0 ? 0.5 : 1)
                    .accessibilityLabel(timer.name + " " + time)
                Spacer(minLength: 0)
                Button { model.toggle(index) } label: {
                    Text(timer.startedAt == nil ? "開始" : "一時停止").frame(minWidth: 48, minHeight: 28)
                }
                    .buttonStyle(.borderedProminent).disabled(timer.countdown && timer.duration <= 0)
                Button { model.reset(index) } label: { Image(systemName: "arrow.counterclockwise").frame(width: 28, height: 28).contentShape(Rectangle()) }
                    .accessibilityLabel(timer.name + "をリセット")
            }
        }.padding(8)
            .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius))
            .overlay(RoundedRectangle(cornerRadius: theme.radius).strokeBorder(theme.edge.opacity(0.14)))
            .classicBevel()

    }
    private func binding<Value>(_ keyPath: WritableKeyPath<UtilityTimer, Value>) -> Binding<Value> {
        Binding(get: {
            (model.timers.first { $0.id == timer.id } ?? timer)[keyPath: keyPath]
        }, set: { value in
            guard let current = model.timers.firstIndex(where: { $0.id == timer.id }) else { return }
            model.timers[current][keyPath: keyPath] = value
            model.save()
        })
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("タイマー名", text: binding(\.name))
                .accessibilityLabel("タイマー名")
            Picker("種類", selection: binding(\.countdown)) {
                Text("カウントダウン").tag(true); Text("ストップウォッチ").tag(false)
            }.pickerStyle(.segmented).disabled(timer.startedAt != nil || timer.elapsed > 0)
            if timer.countdown {
                DurationFields(seconds: binding(\.duration))
                    .disabled(timer.startedAt != nil || timer.elapsed > 0)
                Toggle("画面内で点滅通知", isOn: binding(\.alerts))
                Picker("通知開始", selection: binding(\.warningSeconds)) {
                    Text("終了時").tag(0); Text("残り10秒").tag(10)
                    Text("残り30秒").tag(30); Text("残り1分").tag(60)
                }
            }
            TextField("メモ", text: binding(\.note), axis: .vertical).lineLimit(2...4)
            HStack {
                Button { showsSettings = false; model.move(index, by: -1) } label: { Image(systemName: "arrow.up") }
                    .disabled(index == 0).accessibilityLabel("前へ移動")
                Button { showsSettings = false; model.move(index, by: 1) } label: { Image(systemName: "arrow.down") }
                    .disabled(index == model.timers.count - 1).accessibilityLabel("後へ移動")
                Button("複製") { showsSettings = false; model.duplicate(index) }.disabled(model.timers.count >= 12)
                Spacer()
                Button("削除", role: .destructive) { showsSettings = false; model.remove(index) }
            }
        }.padding(12).frame(width: 300).controlSize(.small)
    }
}

struct DurationFields: View {
    @Binding var seconds: Double
    var body: some View {
        HStack {
            Picker("時", selection: component(3600, limit: 99)) { ForEach(0..<100) { Text("\($0)時").tag($0) } }
            Picker("分", selection: component(60, limit: 59)) { ForEach(0..<60) { Text("\($0)分").tag($0) } }
            Picker("秒", selection: component(1, limit: 59)) { ForEach(0..<60) { Text("\($0)秒").tag($0) } }
        }.labelsHidden().accessibilityElement(children: .contain)
    }
    private func component(_ unit: Int, limit: Int) -> Binding<Int> {
        Binding(get: { Int(seconds) / unit % (unit == 3600 ? 100 : 60) }, set: { value in
            let current = Int(seconds) / unit % (unit == 3600 ? 100 : 60)
            seconds = Double(max(0, Int(seconds) + (min(limit, value) - current) * unit))
        })
    }
}

@MainActor final class FocusTimerModel: ObservableObject {
    @Published var timer = UtilityTimer()
    @Published var now = Date()
    @Published var isBreak = false
    @Published var status = "時間を選んで開始してください"
    @Published var completed = 0
    @Published var breakCelebrationAt: Date?
    @Published var breakFinishedAt: Date?
    @Published var breakEffects: Bool { didSet { defaults.set(breakEffects, forKey: "tools.pomodoro.breakEffects") } }
    @Published var breakSound: Bool { didSet { defaults.set(breakSound, forKey: "tools.pomodoro.breakSound") } }
    var workMinutes = 25
    var breakMinutes = 5
    let pomodoro: Bool
    private var ticker: AnyCancellable?
    private let defaults: UserDefaults
    init(pomodoro: Bool, defaults: UserDefaults = IndependentTools.defaults) {
        self.pomodoro = pomodoro; self.defaults = defaults
        breakEffects = defaults.object(forKey: "tools.pomodoro.breakEffects") as? Bool ?? true
        breakSound = defaults.bool(forKey: "tools.pomodoro.breakSound")
        if pomodoro {
            workMinutes = max(1, min(180, defaults.object(forKey: "tools.pomodoro.work") as? Int ?? 25))
            breakMinutes = max(1, min(60, defaults.object(forKey: "tools.pomodoro.rest") as? Int ?? 5))
        }
        timer.duration = Double(pomodoro ? workMinutes * 60 : 30 * 60)
        refreshCount()
        ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect().sink { [weak self] date in self?.tick(date) }
    }
    private var dayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: now)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
    private func refreshCount() {
        completed = defaults.string(forKey: "tools.pomodoro.day") == dayKey ? defaults.integer(forKey: "tools.pomodoro.count") : 0
    }
    func tick(_ date: Date) {
        now = date; refreshCount()
        guard timer.startedAt != nil && timer.finished(at: date) else { return }
        timer.elapsed = timer.duration; timer.startedAt = nil
        if pomodoro {
            if !isBreak {
                completed += 1; defaults.set(dayKey, forKey: "tools.pomodoro.day"); defaults.set(completed, forKey: "tools.pomodoro.count")
            }
            if isBreak {
                breakFinishedAt = date
                breakCelebrationAt = nil
                if breakSound { NSSound(named: "Pop")?.play() }
            }
            isBreak.toggle(); timer.reset(); timer.duration = Double((isBreak ? breakMinutes : workMinutes) * 60)
            status = isBreak ? "作業完了。休憩を開始できます" : "休憩完了。次の作業を開始できます"
        } else { status = "会議時間が終了しました" }
    }
    func toggle(at date: Date = Date()) {
        now = date
        if timer.startedAt != nil { timer.pause(at: date); status = "一時停止中" }
        else {
            if timer.finished(at: date) { timer.reset() }
            if pomodoro && isBreak && timer.elapsed == 0 { breakCelebrationAt = date }
            breakFinishedAt = nil
            timer.start(at: date)
            status = pomodoro ? (isBreak ? "休憩中" : "集中中") : "会議中"
        }
    }
    func reset() {
        timer.reset(); isBreak = false; breakCelebrationAt = nil; breakFinishedAt = nil
        if pomodoro { timer.duration = Double(workMinutes * 60) }
        status = "時間を選んで開始してください"
    }
    func configure(work: Int, rest: Int) {
        workMinutes = work; breakMinutes = rest
        defaults.set(work, forKey: "tools.pomodoro.work"); defaults.set(rest, forKey: "tools.pomodoro.rest"); reset()
    }
    func stop() { timer.pause(at: Date()); ticker?.cancel(); ticker = nil }
}

struct FocusTimerView: View {
    @ObservedObject var model: FocusTimerModel
    var body: some View {
        Group {
            if model.pomodoro {
                CompactPomodoroView(model: model)
            } else {
                CompactMeetingTimerView(model: model)
            }
        }
    }
}

struct CompactMeetingTimerView: View {
    @ObservedObject var model: FocusTimerModel
    @State private var showsSettings = false
    private var remaining: String {
        let full = UtilityTimer.display(model.timer.remaining(at: model.now))
        return full.hasPrefix("00:") ? String(full.dropFirst(3)) : full
    }
    private var duration: Binding<Double> {
        Binding(get: { model.timer.duration }, set: { model.timer.duration = $0; model.reset() })
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("会議").font(.headline)
                Spacer(minLength: 0)
                Picker("会議時間", selection: duration) {
                    ForEach([15, 30, 45, 60, 90], id: \.self) { minute in
                        Text("\(minute)分").tag(Double(minute * 60))
                    }
                    if ![900.0, 1800, 2700, 3600, 5400].contains(model.timer.duration) {
                        Text("カスタム").tag(model.timer.duration)
                    }
                }.labelsHidden().frame(width: 90).disabled(model.timer.startedAt != nil)
                Button { showsSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("時間を設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("会議時間").font(.headline)
                            DurationFields(seconds: $model.timer.duration)
                                .disabled(model.timer.startedAt != nil || model.timer.elapsed > 0)
                            ThemeMenu()
                            Text("スリープ中も計測。閉じると停止します。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 280)
                    }
            }
            Spacer(minLength: 0)
            Text(remaining)
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                .foregroundStyle(model.timer.finished(at: model.now) ? Color.orange : Color.primary)
                .accessibilityLabel("残り時間 \(remaining)")
            ProgressView(value: model.timer.duration > 0 ? min(1, model.timer.elapsed(at: model.now) / model.timer.duration) : 0)
            Group {
                if model.timer.startedAt != nil {
                    Text("終了予定 \(model.now.addingTimeInterval(model.timer.remaining(at: model.now)), style: .time)")
                } else {
                    Text(model.status == "時間を選んで開始してください" ? "準備完了" : model.status)
                }
            }.font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Button(model.timer.startedAt == nil ? "開始" : "一時停止") { model.toggle() }
                    .buttonStyle(.borderedProminent).disabled(model.timer.duration <= 0)
                Button("リセット") { model.reset() }
            }
        }.padding(10).controlSize(.small)
            .frame(minWidth: 240, idealWidth: 260, minHeight: 210, idealHeight: 210)
    }
}


/// Small timer face; infrequent settings live in a popover to keep the clock visible.
struct CompactPomodoroView: View {
    @ObservedObject var model: FocusTimerModel
    @State private var showsSettings = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var work = 25
    @State private var rest = 5
    private var remaining: String {
        let full = UtilityTimer.display(model.timer.remaining(at: model.now))
        return full.hasPrefix("00:") ? String(full.dropFirst(3)) : full
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(model.isBreak ? "休憩" : "集中").font(.headline)
                Spacer()
                Text("今日 \(model.completed)回").font(.caption).foregroundStyle(.secondary)
                Button { work = model.workMinutes; rest = model.breakMinutes; showsSettings = true } label: {
                    Image(systemName: "gearshape")
                }.accessibilityLabel("時間を設定")
                    .disabled(model.timer.startedAt != nil)
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            Stepper("作業 \(work)分", value: $work, in: 1...180)
                            Stepper("休憩 \(rest)分", value: $rest, in: 1...60)
                            Toggle("花火・終了の光", isOn: $model.breakEffects)
                            Toggle("休憩終了の音", isOn: $model.breakSound)
                            HStack {
                                ThemeMenu()
                                Spacer()
                                Button("適用") { model.configure(work: work, rest: rest); showsSettings = false }
                                    .buttonStyle(.borderedProminent)
                            }
                            Text("スリープ中も計測。閉じると停止。切替後は開始を押してください。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            Spacer(minLength: 0)
            Text(remaining)
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                .accessibilityLabel("残り時間 \(remaining)")
            ProgressView(value: model.timer.duration > 0 ? min(1, model.timer.elapsed(at: model.now) / model.timer.duration) : 0)
            Text(model.isBreak && model.timer.startedAt != nil
                 ? "画面から目を離して、ひと息つこう"
                 : model.status == "時間を選んで開始してください" ? "準備完了" : model.status)
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Button(model.timer.startedAt == nil ? "開始" : "一時停止") { model.toggle() }
                    .buttonStyle(.borderedProminent).disabled(model.timer.duration <= 0)
                Button("リセット") { model.reset() }
            }
        }
        .padding(10).controlSize(.small)
        .background {
            if model.isBreak {
                RoundedRectangle(cornerRadius: 12).fill(Color.cyan.opacity(0.06))
            }
        }
        .overlay {
            if model.breakEffects && !reduceMotion {
                if model.isBreak, let start = model.breakCelebrationAt,
                   model.now.timeIntervalSince(start) < 3 {
                    PomodoroFireworks(start: start)
                }
                if let end = model.breakFinishedAt, model.now.timeIntervalSince(end) < 2 {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(max(0, 1 - model.now.timeIntervalSince(end) / 2)), lineWidth: 2)
                        .padding(2).allowsHitTesting(false).accessibilityHidden(true)
                }
            }
        }
        .frame(minWidth: 240, idealWidth: 260, minHeight: 210, idealHeight: 210)
    }
}

/// A short, silent burst. The timeline exists only during the three-second celebration.
struct PomodoroFireworks: View {
    let start: Date
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                for burst in 0..<3 {
                    let age = elapsed - Double(burst) * 0.45
                    if age >= 0 && age < 1.8 {
                        let progress = age / 1.8
                        let center = CGPoint(x: size.width * [0.22, 0.76, 0.48][burst],
                                             y: size.height * [0.32, 0.26, 0.48][burst])
                        for spark in 0..<18 {
                            let angle = Double(spark) * .pi * 2 / 18
                            let radius = (1 - pow(1 - progress, 3)) * 45
                            let point = CGPoint(x: center.x + cos(angle) * radius,
                                                y: center.y + sin(angle) * radius + progress * progress * 16)
                            let rect = CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3)
                            context.fill(Path(ellipseIn: rect), with: .color((burst == 1 ? Color.blue : Color.cyan).opacity((1 - progress) * 0.85)))
                        }
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true).clipped()
    }
}
