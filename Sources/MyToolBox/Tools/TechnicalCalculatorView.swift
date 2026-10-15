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
