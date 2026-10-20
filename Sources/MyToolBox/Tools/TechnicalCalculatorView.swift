import SwiftUI

struct TechnicalCalculatorView: View {
    let tool: ToolID
    @State private var input = "1 MB"
    @State private var manual = false
    @State private var unit = "MB"
    @State private var integer = "255"
    @State private var sourceBase = 10
    @State private var targetBase = 8
    @State private var data = "1"
    @State private var dataUnit = "GB"
    @State private var reverse = false
    @State private var time = "1"
    @State private var timeUnit = "分"
    @State private var speed = "100"
    @State private var speedUnit = "Mbps"
    @State private var level = 5
    @State private var count = "4"
    @State private var disk = "4"
    @State private var diskUnit = "TB"
    @State private var rate = "99.9"
    @State private var copied = false
    private typealias Calc = TechnicalCalculators
    private var results: Result<[(String, String)], Error> {
        Result {
            switch tool {
            case .byteConverter:
                let bytes = try Calc.bytes(input, unit: manual ? unit : nil)
                return Calc.units.map { ($0, Calc.display(bytes / Calc.factor($0))) }
            case .numberBaseConverter:
                return try Array(Set([2, 10, 12, 16, 24, 60, targetBase])).sorted().map { ("\($0)進数", try Calc.base(integer, from: sourceBase, to: $0)) }
            case .bandwidthCalculator:
                let bytes = try Calc.bytes(data, unit: dataUnit)
                if reverse {
                    let factor: Double = speedUnit == "Mbps" ? 1e6 : speedUnit == "Gbps" ? 1e9 : speedUnit == "MB/s" ? 8e6 : 8e9
                    let seconds = try Calc.transferTime(bytes: bytes, bitsPerSecond: Calc.number(speed, positive: true) * factor)
                    return [("転送時間", Calc.duration(seconds)), ("秒", Calc.display(seconds))]
                }
                let seconds = try Calc.number(time, positive: true) * (timeUnit == "秒" ? 1 : timeUnit == "分" ? 60 : 3600)
                let bits = try Calc.bandwidth(bytes: bytes, seconds: seconds)
                return [("必要な帯域幅", Calc.display(bits / 1e6) + " Mbps"), ("GBit/s", Calc.display(bits / 1e9) + " Gbps"), ("転送速度", Calc.display(bits / 8e6) + " MB/s")]
            case .raidCalculator:
                guard let n = Int(count) else { throw Calc.Failure.invalid("台数は整数で入力してください。") }
                let result = try Calc.raid(level: level, count: n, size: Calc.number(disk, positive: true))
                return [("使用可能容量", Calc.display(result.usable) + " " + diskUnit), ("総容量", Calc.display(result.raw) + " " + diskUnit), ("利用効率", Calc.display(result.efficiency) + "%"), ("耐障害性", result.faults)]
            case .slaCalculator:
                let value = try Calc.number(rate)
                return try [("1日", 1.0), ("1週間", 7.0), ("1か月（30日）", 30.0), ("1年間（365日）", 365.0)].map { ($0.0, Calc.duration(try Calc.downtime(rate: value, days: $0.1))) }
            default: return []
            }
        }
    }
    var body: some View {
        Group {
            if tool == .byteConverter {
                CompactByteConverterView()
            } else if tool == .numberBaseConverter {
                CompactNumberBaseConverterView()
            } else if tool == .bandwidthCalculator {
                CompactBandwidthCalculatorView()
            } else if tool == .raidCalculator {
                CompactRAIDCalculatorView()
            } else if tool == .slaCalculator {
                CompactSLACalculatorView()
            } else {
        ToolPage(tool.title, subtitle: tool.subtitle, symbol: tool.symbol, tint: .cyan) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ToolCard { VStack(alignment: .leading, spacing: 16) { controls } }
                    switch results {
                    case .success(let rows):
                        ToolCard {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(rows.indices, id: \.self) { index in
                                    HStack(alignment: .top) {
                                        Text(rows[index].0).foregroundStyle(.secondary).frame(width: 145, alignment: .leading)
                                        Text(rows[index].1).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                        Button("コピー") { copy(rows[index].1) }
                                    }
                                }
                            }
                        }
                        HStack { Spacer(); Text(copied ? "コピーしました" : "").font(.caption); Button("すべてコピー") { copy(rows.map { $0.0 + ": " + $0.1 }.joined(separator: "\n")) } }
                    case .failure(let error): Label(error.localizedDescription, systemImage: "exclamationmark.circle").foregroundStyle(.red)
                    }
                    ToolFootnote(text: footnote)
                }.padding(24)
            }
        }.frame(minWidth: 780, minHeight: 700)
            }
        }
    }
    @ViewBuilder private var controls: some View {
        switch tool {
        case .byteConverter:
            Toggle("単位をプルダウンで指定", isOn: $manual)
            field("変換する値", text: $input)
            if manual { picker("入力単位", value: $unit, choices: Calc.units) }
        case .numberBaseConverter:
            Stepper("入力の基数: \(sourceBase)", value: $sourceBase, in: 2...60)
            field("整数", text: $integer)
            Stepper("追加の出力基数: \(targetBase)", value: $targetBase, in: 2...60)
        case .bandwidthCalculator:
            Toggle("帯域幅から転送時間を求める", isOn: $reverse)
            field("データ容量", text: $data)
            picker("容量単位", value: $dataUnit, choices: ["MB", "GB", "TB"])
            if reverse {
                field("帯域幅", text: $speed)
                picker("帯域単位", value: $speedUnit, choices: ["Mbps", "Gbps", "MB/s", "GB/s"])
            } else {
                field("転送時間", text: $time)
                picker("時間単位", value: $timeUnit, choices: ["秒", "分", "時間"])
            }
        case .raidCalculator:
            ThemePicker("RAIDレベル", selection: $level, options: [0, 1, 5, 6, 10].map { ($0, "RAID \($0)") }, tabs: true)
            field("ディスク台数", text: $count)
            field("1台あたりの容量", text: $disk)
            picker("容量単位", value: $diskUnit, choices: ["GB", "TB"])
        case .slaCalculator:
            field("目標稼働率（%）", text: $rate)
            HStack { ForEach(["99", "99.9", "99.99", "99.999"], id: \.self) { preset in Button(preset + "%") { rate = preset } } }
        default: EmptyView()
        }
    }
    private func field(_ title: String, text: Binding<String>) -> some View {
        HStack { Text(title).frame(width: 160, alignment: .leading); TextField(title, text: text).textFieldStyle(.roundedBorder) }
    }
    private func picker(_ title: String, value: Binding<String>, choices: [String]) -> some View {
        ThemePicker(title, selection: value, options: choices.map { ($0, $0) })
    }
    private func copy(_ value: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(value, forType: .string); copied = true }
    private var footnote: String {
        switch tool {
        case .byteConverter: return "KB〜TBは1000倍、KiB〜TiBは1024倍。自動読み取り例: 1 MB、1024KiB。単位なしはB。小数は近似値です。"
        case .numberBaseConverter: return "整数のみ・最大1024桁。数字は0–9、A–Z、a–x。36進数以下は大文字小文字を区別せず、37進数以上は区別します。0b／0x、10進数のカンマに対応。"
        case .bandwidthCalculator: return "1 byte = 8 bits、容量は1000倍。通信のオーバーヘッドや実効速度の低下を含まない理論値です。"
        case .raidCalculator: return "全ディスクが同容量の場合の理論値です。混在時は最小容量を入力してください。フォーマット・管理領域を含みません。RAID 1は全台ミラー。RAIDはバックアップの代替にはなりません。"
        default: return "停止可能時間 = 期間 ×（100 − 稼働率）÷ 100。月は30日、年は365日。表示は秒単位に丸め、1秒未満は小数で表示します。"
        }
    }
}


struct CompactByteConverterView: View {
    @State private var input: String
    @State private var unit: String
    @State private var copied = false
    @State private var showsSettings = false
    init(input: String = "1 MB", unit: String = "自動") {
        _input = State(initialValue: input); _unit = State(initialValue: unit)
    }
    private var results: Result<[(String, String)], Error> {
        Result {
            let bytes = try TechnicalCalculators.bytes(input, unit: unit == "自動" ? nil : unit)
            return TechnicalCalculators.units.map { ($0, TechnicalCalculators.display(bytes / TechnicalCalculators.factor($0))) }
        }
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("容量変換").font(.headline)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("容量変換の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            ThemeMenu()
                            Text("自動の例：1 MB、1024KiB。単位なしはB。単位を選んだ場合は数値だけ入力します。KB〜TBは1000倍、KiB〜TiBは1024倍。小数は近似値です。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            HStack(spacing: 8) {
                TextField(unit == "自動" ? "1 MB / 1024KiB" : "数値", text: $input)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("変換する値")
                Picker("入力単位", selection: $unit) {
                    Text("自動").tag("自動")
                    ForEach(TechnicalCalculators.units, id: \.self) { Text($0).tag($0) }
                }.labelsHidden().frame(width: 85)
            }
            switch results {
            case .success(let rows):
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(rows.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                Text(rows[index].0).font(.caption).foregroundStyle(.secondary)
                                    .frame(width: 32, alignment: .leading)
                                Text(rows[index].1).font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button { copy(rows[index].1) } label: {
                                    Image(systemName: "doc.on.doc").frame(width: 28, height: 28).contentShape(Rectangle())
                                }.accessibilityLabel(rows[index].0 + "の値をコピー")
                            }
                        }
                    }
                }
                HStack {
                    Text(copied ? "コピーしました" : "").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button { copy(rows.map { $0.0 + ": " + $0.1 }.joined(separator: "\n")) } label: {
                        Text("すべてコピー").frame(minHeight: 28)
                    }
                }
            case .failure(let error):
                Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 300, idealWidth: 320, minHeight: 300, idealHeight: 360)
            .onChange(of: input) { _, _ in copied = false }
            .onChange(of: unit) { _, _ in copied = false }
    }
    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        copied = NSPasteboard.general.setString(value, forType: .string)
    }
}


struct CompactNumberBaseConverterView: View {
    @State private var input: String
    @State private var sourceBase: Int
    @State private var targetBase: Int
    @State private var copied = false
    @State private var showsSettings = false
    init(input: String = "255", sourceBase: Int = 10, targetBase: Int = 8) {
        _input = State(initialValue: input); _sourceBase = State(initialValue: sourceBase)
        _targetBase = State(initialValue: targetBase)
    }
    private var results: Result<[(String, String)], Error> {
        Result {
            try Array(Set([2, 10, 12, 16, 24, 60, targetBase])).sorted().map {
                ("\($0)進数", try TechnicalCalculators.base(input, from: sourceBase, to: $0))
            }
        }
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("進数変換").font(.headline)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("進数変換の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("追加の出力基数", selection: $targetBase) {
                                ForEach(2...60, id: \.self) { Text("\($0)進数").tag($0) }
                            }
                            ThemeMenu()
                            Text("整数のみ・最大1024桁。2・10・12・16・24・60進数と追加の基数へ変換します。数字は0–9、A–Z、a–x。36進以下は大小区別なし、37進以上は区別します。0b／0x、10進数のカンマに対応。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            HStack(spacing: 8) {
                TextField("整数", text: $input).textFieldStyle(.roundedBorder).accessibilityLabel("変換する整数")
                Picker("入力基数", selection: $sourceBase) {
                    ForEach(2...60, id: \.self) { Text("\($0)進数").tag($0) }
                }.labelsHidden().frame(width: 85).help("入力基数")
            }

            switch results {
            case .success(let rows):
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(rows.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 8) {
                                Text(rows[index].0).font(.caption).foregroundStyle(.secondary)
                                    .frame(width: 42, alignment: .leading)
                                Text(rows[index].1).font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button { copy(rows[index].1) } label: {
                                    Image(systemName: "doc.on.doc").frame(width: 28, height: 28).contentShape(Rectangle())
                                }.accessibilityLabel(rows[index].0 + "の値をコピー")
                            }
                        }
                    }
                }
                HStack {
                    Text(copied ? "コピーしました" : "").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button { copy(rows.map { $0.0 + ": " + $0.1 }.joined(separator: "\n")) } label: {
                        Text("すべてコピー").frame(minHeight: 28)
                    }
                }
            case .failure(let error):
                Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 300, idealWidth: 320, minHeight: 300, idealHeight: 360)
            .onChange(of: input) { _, _ in copied = false }
            .onChange(of: sourceBase) { _, _ in copied = false }
            .onChange(of: targetBase) { _, _ in copied = false }
    }
    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        copied = NSPasteboard.general.setString(value, forType: .string)
    }
}


struct CompactBandwidthCalculatorView: View {
    @State private var data: String
    @State private var dataUnit = "GB"
    @State private var reverse: Bool
    @State private var time = "1"
    @State private var timeUnit = "分"
    @State private var speed = "100"
    @State private var speedUnit = "Mbps"
    @State private var copied = false
    @State private var showsSettings = false
    init(reverse: Bool = false, data: String = "1") {
        _reverse = State(initialValue: reverse); _data = State(initialValue: data)
    }
    private var results: Result<[(String, String)], Error> {
        Result {
            let bytes = try TechnicalCalculators.bytes(data, unit: dataUnit)
            if reverse {
                let factor: Double = speedUnit == "Mbps" ? 1e6 : speedUnit == "Gbps" ? 1e9 : speedUnit == "MB/s" ? 8e6 : 8e9
                let seconds = try TechnicalCalculators.transferTime(bytes: bytes, bitsPerSecond: TechnicalCalculators.number(speed, positive: true) * factor)
                return [("転送時間", TechnicalCalculators.duration(seconds)), ("秒", TechnicalCalculators.display(seconds))]
            }
            let seconds = try TechnicalCalculators.number(time, positive: true) * (timeUnit == "秒" ? 1 : timeUnit == "分" ? 60 : 3600)
            let bits = try TechnicalCalculators.bandwidth(bytes: bytes, seconds: seconds)
            return [("必要な帯域幅", TechnicalCalculators.display(bits / 1e6) + " Mbps"),
                    ("GBit/s", TechnicalCalculators.display(bits / 1e9) + " Gbps"),
                    ("転送速度", TechnicalCalculators.display(bits / 8e6) + " MB/s")]
        }
    }
    private var inputKey: [String] { [data, dataUnit, String(reverse), time, timeUnit, speed, speedUnit] }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("帯域・転送時間").font(.headline)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("帯域計算の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            ThemeMenu()
                            Text("1 byte = 8 bits、容量は1000倍。通信のオーバーヘッドや実効速度の低下を含まない理論値です。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            Picker("計算方法", selection: $reverse) {
                Text("必要な帯域").tag(false); Text("転送時間").tag(true)
            }.pickerStyle(.segmented).labelsHidden()
            inputRow("容量", value: $data, unit: $dataUnit, choices: ["MB", "GB", "TB"])
            if reverse {
                inputRow("速度", value: $speed, unit: $speedUnit, choices: ["Mbps", "Gbps", "MB/s", "GB/s"])
            } else {
                inputRow("時間", value: $time, unit: $timeUnit, choices: ["秒", "分", "時間"])
            }
            switch results {
            case .success(let rows):
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(rows.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(rows[index].0).font(.caption).foregroundStyle(.secondary)
                                    Text(rows[index].1).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Button { copy(rows[index].1) } label: {
                                    Image(systemName: "doc.on.doc").frame(width: 28, height: 28).contentShape(Rectangle())
                                }.accessibilityLabel(rows[index].0 + "をコピー")
                            }
                        }
                    }
                }
                HStack {
                    Text(copied ? "コピーしました" : "").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button { copy(rows.map { $0.0 + ": " + $0.1 }.joined(separator: "\n")) } label: {
                        Text("すべてコピー").frame(minHeight: 28)
                    }
                }
            case .failure(let error):
                Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 300, idealWidth: 320, minHeight: 320, idealHeight: 360)
            .onChange(of: inputKey) { _, _ in copied = false }
    }
    private func inputRow(_ title: String, value: Binding<String>, unit: Binding<String>, choices: [String]) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.caption).frame(width: 28, alignment: .leading)
            TextField(title, text: value).textFieldStyle(.roundedBorder).accessibilityLabel(title)
            Picker(title + "の単位", selection: unit) {
                ForEach(choices, id: \.self) { Text($0).tag($0) }
            }.labelsHidden().frame(width: 90)
        }
    }
    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        copied = NSPasteboard.general.setString(value, forType: .string)
    }
}


struct CompactRAIDCalculatorView: View {
    @State private var level: Int
    @State private var count: String
    @State private var disk: String
    @State private var diskUnit = "TB"
    @State private var copied = false
    @State private var showsSettings = false
    init(level: Int = 5, count: String = "4", disk: String = "4") {
        _level = State(initialValue: level); _count = State(initialValue: count); _disk = State(initialValue: disk)
    }
    private var results: Result<[(String, String)], Error> {
        Result {
            guard let n = Int(count) else { throw TechnicalCalculators.Failure.invalid("台数は整数で入力してください。") }
            let result = try TechnicalCalculators.raid(level: level, count: n, size: TechnicalCalculators.number(disk, positive: true))
            return [("使用可能容量", TechnicalCalculators.display(result.usable) + " " + diskUnit),
                    ("総容量", TechnicalCalculators.display(result.raw) + " " + diskUnit),
                    ("利用効率", TechnicalCalculators.display(result.efficiency) + "%"), ("耐障害性", result.faults)]
        }
    }
    private var inputKey: [String] { [String(level), count, disk, diskUnit] }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("RAID計算").font(.headline)
                Spacer()
                Picker("RAIDレベル", selection: $level) {
                    ForEach([0, 1, 5, 6, 10], id: \.self) { Text("RAID \($0)").tag($0) }
                }.labelsHidden().frame(width: 90)
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("RAID計算の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            ThemeMenu()
                            Text("全ディスクが同容量の場合の理論値です。混在時は最小容量を入力してください。フォーマット・管理領域を含みません。RAID 1は全台ミラー。RAIDはバックアップの代替にはなりません。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            HStack(spacing: 8) {
                Text("台数").font(.caption).frame(width: 28, alignment: .leading)
                TextField("ディスク台数", text: $count).textFieldStyle(.roundedBorder).accessibilityLabel("ディスク台数")
                Text("台").font(.caption).foregroundStyle(.secondary).frame(width: 90)
            }
            inputRow("容量", value: $disk, unit: $diskUnit, choices: ["GB", "TB"])
                .help("1台あたりの容量")
            switch results {
            case .success(let rows):
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(rows.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(rows[index].0).font(.caption).foregroundStyle(.secondary)
                                    Text(rows[index].1).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Button { copy(rows[index].1) } label: {
                                    Image(systemName: "doc.on.doc").frame(width: 28, height: 28).contentShape(Rectangle())
                                }.accessibilityLabel(rows[index].0 + "をコピー")
                            }
                        }
                    }
                }
                HStack {
                    Text(copied ? "コピーしました" : "").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button { copy(rows.map { $0.0 + ": " + $0.1 }.joined(separator: "\n")) } label: {
                        Text("すべてコピー").frame(minHeight: 28)
                    }
                }
            case .failure(let error):
                Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 300, idealWidth: 320, minHeight: 320, idealHeight: 360)
            .onChange(of: inputKey) { _, _ in copied = false }
    }
    private func inputRow(_ title: String, value: Binding<String>, unit: Binding<String>, choices: [String]) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.caption).frame(width: 28, alignment: .leading)
            TextField(title, text: value).textFieldStyle(.roundedBorder).accessibilityLabel(title)
            Picker(title + "の単位", selection: unit) {
                ForEach(choices, id: \.self) { Text($0).tag($0) }
            }.labelsHidden().frame(width: 90)
        }
    }
    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        copied = NSPasteboard.general.setString(value, forType: .string)
    }
}


struct CompactSLACalculatorView: View {
    @State private var rate: String
    @State private var copied = false
    @State private var showsSettings = false
    private let presets = ["99", "99.9", "99.99", "99.999"]
    init(rate: String = "99.9") { _rate = State(initialValue: rate) }
    private var results: Result<[(String, String)], Error> {
        Result {
            let value = try TechnicalCalculators.number(rate)
            return try [("1日", 1.0), ("1週間", 7.0), ("1か月（30日）", 30.0), ("1年間（365日）", 365.0)].map {
                ($0.0, TechnicalCalculators.duration(try TechnicalCalculators.downtime(rate: value, days: $0.1)))
            }
        }
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("SLA計算").font(.headline)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("SLA計算の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            ThemeMenu()
                            Text("停止可能時間 = 期間 ×（100 − 稼働率）÷ 100。稼働率は0〜100%。月は30日、年は365日で計算します。秒単位に丸め、1秒未満は小数で表示します。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            HStack(spacing: 8) {
                TextField("稼働率", text: $rate).textFieldStyle(.roundedBorder).accessibilityLabel("目標稼働率")
                Text("%").foregroundStyle(.secondary)
                Picker("稼働率プリセット", selection: $rate) {
                    ForEach(presets, id: \.self) { Text($0 + "%").tag($0) }
                    if !presets.contains(rate) { Text("カスタム").tag(rate) }
                }.labelsHidden().frame(width: 110)
            }
            switch results {
            case .success(let rows):
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(rows.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(rows[index].0).font(.caption).foregroundStyle(.secondary)
                                    Text(rows[index].1).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Button { copy(rows[index].1) } label: {
                                    Image(systemName: "doc.on.doc").frame(width: 28, height: 28).contentShape(Rectangle())
                                }.accessibilityLabel(rows[index].0 + "をコピー")
                            }
                        }
                    }
                }
                HStack {
                    Text(copied ? "コピーしました" : "").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button { copy(rows.map { $0.0 + ": " + $0.1 }.joined(separator: "\n")) } label: {
                        Text("すべてコピー").frame(minHeight: 28)
                    }
                }
            case .failure(let error):
                Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 300, idealWidth: 320, minHeight: 320, idealHeight: 360)
            .onChange(of: rate) { _, _ in copied = false }
    }
    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        copied = NSPasteboard.general.setString(value, forType: .string)
    }
}
