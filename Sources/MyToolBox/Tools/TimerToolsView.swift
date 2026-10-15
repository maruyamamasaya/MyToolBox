import SwiftUI
import Combine

@MainActor final class TimerBoardModel: ObservableObject {
    @Published var timers: [UtilityTimer] = []
    @Published var now = Date()
    @Published var message = ""
    private var ticker: AnyCancellable?
    private let defaults: UserDefaults
    private let key = "tools.timerBoard.v1"
    init(defaults: UserDefaults = .standard) {
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
    var body: some View {
        ToolPage("タイマーボード", subtitle: "複数のカウントダウン・ストップウォッチをまとめて管理", symbol: "square.grid.2x2", tint: .orange) {
            VStack(spacing: 14) {
                HStack {
                    Text("\(model.timers.count) / 12")
                    Spacer()
                    Button("すべて一時停止") { model.pauseAll() }
                    Button("完了をリセット") { model.resetAll(finishedOnly: true) }
                    Button("すべてリセット") { model.resetAll(finishedOnly: false) }
                    Button("追加", systemImage: "plus") { model.add() }.disabled(model.timers.count >= 12)
                }
                if !model.message.isEmpty { Text(model.message).foregroundStyle(.orange).accessibilityAddTraits(.updatesFrequently) }
                ScrollView {
                    if model.timers.isEmpty {
                        VStack(spacing: 18) {
                            Text("最初のタイマーを追加しましょう").font(.title2)
                            Text("時間を設定して開始。最大12個を同時に使えます。").foregroundStyle(.secondary)
                            Button("タイマーを追加", systemImage: "plus") { model.add() }.buttonStyle(.borderedProminent)
                        }.frame(maxWidth: .infinity).padding(60)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), alignment: .top)], spacing: 14) {
                        ForEach(Array(model.timers.enumerated()), id: \.element.id) { index, timer in
                            TimerBoardCard(model: model, index: index, timer: timer)
                        }
                    }
                }
                ToolFootnote(text: "設定と実行状態は自動保存。スリープ中・アプリ終了中も経過時間に含みます。ウィンドウを閉じると一時停止します。通知は画面内の色と表示です。")
            }.padding(22)
        }.frame(minWidth: 760, idealWidth: 880, minHeight: 600, idealHeight: 720)
    }
}

private struct TimerBoardCard: View {
    @ObservedObject var model: TimerBoardModel
    let index: Int
    let timer: UtilityTimer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var finished: Bool { timer.finished(at: model.now) }
    private var warning: Bool { timer.countdown && timer.alerts && (timer.startedAt != nil || finished) && timer.remaining(at: model.now) <= Double(timer.warningSeconds) }
    var body: some View {
        ToolCard {
            VStack(spacing: 12) {
                TextField("タイマー名", text: $model.timers[index].name).font(.headline)
                Picker("種類", selection: $model.timers[index].countdown) { Text("カウントダウン").tag(true); Text("ストップウォッチ").tag(false) }
                    .pickerStyle(.segmented).disabled(timer.startedAt != nil || timer.elapsed > 0)
                Text(UtilityTimer.display(timer.countdown ? timer.remaining(at: model.now) : timer.elapsed(at: model.now)))
                    .font(.system(size: 40, weight: .medium, design: .monospaced)).minimumScaleFactor(0.6).lineLimit(1)
                    .foregroundStyle(warning ? Color.orange : Color.primary)
                    .opacity(warning && !reduceMotion && Int(model.now.timeIntervalSince1970 * 2) % 2 == 0 ? 0.5 : 1)
                Text(finished ? "終了しました" : timer.startedAt != nil ? "計測中" : timer.elapsed > 0 ? "一時停止中" : "準備完了").foregroundStyle(.secondary)
                HStack {
                    Button(timer.startedAt == nil ? "開始" : "一時停止") { model.toggle(index) }.buttonStyle(.borderedProminent).disabled(timer.countdown && timer.duration <= 0)
                    Button("リセット") { model.reset(index) }
                }
                DisclosureGroup("設定") {
                    VStack(alignment: .leading, spacing: 10) {
                        if timer.countdown {
                            DurationFields(seconds: $model.timers[index].duration).disabled(timer.startedAt != nil || timer.elapsed > 0)
                            Toggle("画面内で点滅通知", isOn: $model.timers[index].alerts)
                            Picker("通知開始", selection: $model.timers[index].warningSeconds) {
                                Text("終了時").tag(0); Text("残り10秒").tag(10); Text("残り30秒").tag(30); Text("残り1分").tag(60)
                            }
                        }
                        TextField("メモ", text: $model.timers[index].note, axis: .vertical).lineLimit(2...4)
                        HStack {
                            Button { model.move(index, by: -1) } label: { Image(systemName: "arrow.up") }.disabled(index == 0).help("前へ移動")
                            Button { model.move(index, by: 1) } label: { Image(systemName: "arrow.down") }.disabled(index == model.timers.count - 1).help("後へ移動")
                            Button("複製") { model.duplicate(index) }.disabled(model.timers.count >= 12)
                            Spacer()
                            Button("削除", role: .destructive) { model.remove(index) }
                        }
                    }.padding(.top, 10)
                }
            }
        }.onChange(of: timer.name) { _, _ in model.save() }
            .onChange(of: timer.note) { _, _ in model.save() }
            .onChange(of: timer.duration) { _, _ in model.save() }
            .onChange(of: timer.countdown) { _, _ in model.save() }
            .onChange(of: timer.alerts) { _, _ in model.save() }
            .onChange(of: timer.warningSeconds) { _, _ in model.save() }
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
    var workMinutes = 25
    var breakMinutes = 5
    let pomodoro: Bool
    private var ticker: AnyCancellable?
    private let defaults: UserDefaults
    init(pomodoro: Bool, defaults: UserDefaults = .standard) {
        self.pomodoro = pomodoro; self.defaults = defaults
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
            isBreak.toggle(); timer.reset(); timer.duration = Double((isBreak ? breakMinutes : workMinutes) * 60)
            status = isBreak ? "作業完了。休憩を開始できます" : "休憩完了。次の作業を開始できます"
        } else { status = "会議時間が終了しました" }
    }
    func toggle() {
        if timer.startedAt != nil { timer.pause(at: Date()); status = "一時停止中" }
        else { if timer.finished(at: Date()) { timer.reset() }; timer.start(at: Date()); status = pomodoro ? (isBreak ? "休憩中" : "集中中") : "会議中" }
    }
    func reset() { timer.reset(); isBreak = false; if pomodoro { timer.duration = Double(workMinutes * 60) }; status = "時間を選んで開始してください" }
    func configure(work: Int, rest: Int) {
        workMinutes = work; breakMinutes = rest
        defaults.set(work, forKey: "tools.pomodoro.work"); defaults.set(rest, forKey: "tools.pomodoro.rest"); reset()
    }
    func stop() { timer.pause(at: Date()); ticker?.cancel(); ticker = nil }
}

struct FocusTimerView: View {
    @ObservedObject var model: FocusTimerModel
    @State private var work = 25
    @State private var rest = 5
    var body: some View {
        ToolPage(model.pomodoro ? "ポモドーロタイマー" : "会議タイマー", subtitle: model.pomodoro ? "集中と休憩を、自分のリズムで" : "時間を選んで開始。会議の残り時間をひと目で", symbol: model.pomodoro ? "timer" : "person.3", tint: .orange) {
            VStack(spacing: 20) {
                if !model.pomodoro {
                    HStack {
                        ForEach([15, 30, 45, 60, 90], id: \.self) { minute in
                            Button("\(minute)分") { model.timer.duration = Double(minute * 60); model.reset() }
                                .buttonStyle(.bordered).tint(model.timer.duration == Double(minute * 60) ? .orange : .secondary)
                        }
                    }.disabled(model.timer.startedAt != nil)
                    DurationFields(seconds: $model.timer.duration).disabled(model.timer.startedAt != nil || model.timer.elapsed > 0)
                }
                ToolCard {
                    VStack(spacing: 20) {
                        Text(model.pomodoro ? (model.isBreak ? "休憩" : "作業") : "会議終了まで").font(.title2)
                        Text(UtilityTimer.display(model.timer.remaining(at: model.now)))
                            .font(.system(size: 76, weight: .medium, design: .monospaced)).minimumScaleFactor(0.5).lineLimit(1)
                            .foregroundStyle(model.timer.finished(at: model.now) ? Color.orange : Color.primary)
                        if !model.pomodoro, model.timer.startedAt != nil {
                            Text("終了予定 \(model.now.addingTimeInterval(model.timer.remaining(at: model.now)), style: .time)").font(.title3)
                        }
                        ProgressView(value: model.timer.duration > 0 ? min(1, model.timer.elapsed(at: model.now) / model.timer.duration) : 0)
                        Text(model.status).foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            Button(model.timer.startedAt == nil ? "開始" : "一時停止") { model.toggle() }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.timer.duration <= 0)
                            Button("リセット") { model.reset() }.controlSize(.large)
                        }
                    }.frame(maxWidth: .infinity).padding(.vertical, 18)
                }
                if model.pomodoro {
                    HStack { Text("今日の完了セッション"); Spacer(); Text("\(model.completed) 回").font(.title2.bold()) }
                    DisclosureGroup("時間を設定") {
                        HStack {
                            Stepper("作業 \(work)分", value: $work, in: 1...180)
                            Stepper("休憩 \(rest)分", value: $rest, in: 1...60)
                            Button("適用") { model.configure(work: work, rest: rest) }
                        }.padding(.top, 12)
                    }.disabled(model.timer.startedAt != nil)
                }
                ToolFootnote(text: "スリープ中も経過時間に含みます。終了は画面内で表示。ウィンドウを閉じると計測を終了します。" + (model.pomodoro ? " 作業・休憩の切替後は「開始」を押してください。" : ""))
            }.padding(26)
        }.frame(minWidth: 650, idealWidth: 720, minHeight: 600)
            .onAppear { work = model.workMinutes; rest = model.breakMinutes }
    }
}
