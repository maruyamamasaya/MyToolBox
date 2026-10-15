import Foundation

enum ToolCategory: String, CaseIterable, Identifiable {
    case text = "テキスト・CSV"
    case calculation = "計算・変換"
    case design = "画像・デザイン"
    case system = "システム・音声"
    case server = "ネットワーク・サーバー"
    case calendar = "日付・予定"
    var id: String { rawValue }
    var tools: [ToolID] { ToolID.allCases.filter { $0.category == self } }
}

/// Installed tools only; each route has a native implementation.
enum ToolID: String, CaseIterable, Identifiable {
    case hashGenerator, testDataGenerator
    case cidrAnalyzer, dnsRecordBuilder, unitConverter, percentageCalculator, simpleCalculator, numberCalculator, cronReader, linuxCommands, chmodCalculator, directoryTree, unixTimeConverter
    case randomNumberGenerator, portNumberFinder, httpStatusViewer, localMemo, systemMonitor, businessDays, audioCheck, microphoneCheck, csvViewer, csvEditor, sequentialText, clipboardFormatter, textCleaner, lineTools, stringReplacer, comparison, textCodec, colorPalette, userAgent, imageResizer, byteConverter, numberBaseConverter, bandwidthCalculator, raidCalculator, slaCalculator, pomodoroTimer, timerBoard, meetingTimer, timeCalculator
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cidrAnalyzer: return "CIDR解析"
        case .dnsRecordBuilder: return "DNSレコード作成"
        case .unitConverter: return "単位変換"
        case .percentageCalculator: return "パーセント計算"
        case .simpleCalculator: return "電卓"
        case .numberCalculator: return "数値集計"
        case .cronReader: return "Cron解読・作成"
        case .linuxCommands: return "Linuxコマンド辞典"
        case .chmodCalculator: return "chmod計算"
        case .directoryTree: return "ディレクトリツリー作成"
        case .unixTimeConverter: return "Unix時刻変換"
        case .randomNumberGenerator: return "乱数ジェネレーター"
        case .pomodoroTimer: return "ポモドーロタイマー"
        case .timerBoard: return "タイマーボード"
        case .meetingTimer: return "会議タイマー"
        case .timeCalculator: return "時間計算"
        case .byteConverter: return "容量単位変換"
        case .numberBaseConverter: return "進数変換"
        case .bandwidthCalculator: return "帯域・転送時間計算"
        case .raidCalculator: return "RAID計算"
        case .slaCalculator: return "SLA計算"
        case .portNumberFinder: return "ポート番号検索"
        case .httpStatusViewer: return "HTTPステータス一覧"
        case .hashGenerator: return "ハッシュ生成"
        case .testDataGenerator: return "テストデータ生成"
        case .localMemo: return "ローカルメモ"
        case .systemMonitor: return "システムモニター"
        case .businessDays: return "カレンダー"
        case .audioCheck: return "オーディオチェック"
        case .microphoneCheck: return "マイクチェック"
        case .csvViewer: return "CSVビューワー"
        case .csvEditor: return "CSVエディター"
        case .sequentialText: return "連番テキスト生成"
        case .clipboardFormatter: return "クリップボード整形"
        case .textCleaner: return "テキストクリーナー"
        case .lineTools: return "行ツール"
        case .stringReplacer: return "検索・置換"
        case .textCodec: return "テキスト変換"
        case .imageResizer: return "画像リサイズ"
        case .userAgent: return "User-Agent Viewer"
        case .colorPalette: return "カラーパレット"
        case .comparison: return "比較ツール"
        }
    }
    var subtitle: String {
        switch self {
        case .cidrAnalyzer: return "IPv4の範囲・グループ・包含関係"
        case .dnsRecordBuilder: return "A・AAAA・CNAME・MX・TXTのゾーン出力"
        case .unitConverter: return "長さ・重さ・温度など10カテゴリを換算"
        case .percentageCalculator: return "増減率・割合・○%計算・逆算"
        case .simpleCalculator: return "括弧・四則演算・計算履歴"
        case .numberCalculator: return "合計・平均・中央値・最大・最小・範囲"
        case .cronReader: return "5フィールドの条件・次回予定・式の作成"
        case .linuxCommands: return "主要40コマンドの用途・オプションを検索"
        case .chmodCalculator: return "8進数・rwx・特殊ビットを相互変換"
        case .directoryTree: return "構成編集・7出力形式・JSON保存"
        case .unixTimeConverter: return "秒・ミリ秒・日本時間・UTCの相互変換"
        case .randomNumberGenerator: return "範囲・1〜32桁指定・個数・区切り形式・コピー"
        case .pomodoroTimer: return "集中・休憩の切替と今日の完了回数"
        case .timerBoard: return "最大12個のタイマー・ストップウォッチ"
        case .meetingTimer: return "時間を選んで開始・残り時間と終了予定"
        case .timeCalculator: return "勤務時間・日付またぎ・時間帯の合計"
        case .byteConverter: return "B・KB・MiBなどの容量を相互変換"
        case .numberBaseConverter: return "2〜60進数の整数を正確に変換"
        case .bandwidthCalculator: return "必要な帯域幅・転送時間を計算"
        case .raidCalculator: return "ディスク構成の容量・耐障害性を確認"
        case .slaCalculator: return "稼働率から日・週・月・年の停止時間を計算"
        case .portNumberFinder: return "ポート番号・サービス名の検索とTCP/UDP絞り込み"
        case .httpStatusViewer: return "HTTPコードの意味・説明・1xx〜5xx分類"
        case .hashGenerator: return "SHA-1/256/384/512・HEX/Base64"
        case .testDataGenerator: return "ダミー文章・文字列・CSV・UUID v4を生成"
        case .localMemo: return "複数メモ・自動保存・履歴・JSONバックアップ"
        case .systemMonitor: return "CPU・メモリ・通信・温度を確認"
        case .businessDays: return "日程候補の作成・営業日計算"
        case .audioCheck: return "左右のスピーカーと出力装置を確認"
        case .microphoneCheck: return "入力レベル・10秒録音で声を確認"
        case .csvViewer: return "CSVを表で表示・検索・並べ替え"
        case .csvEditor: return "セル・行・列を編集してローカル保存"
        case .sequentialText: return "各行に連番・前後の文字を追加"
        case .clipboardFormatter: return "表整形・リスト変換・JSONやSQL形式へ"
        case .textCleaner: return "不可視文字・空行・箇条書きを整理"
        case .lineTools: return "並べ替え・行抽出・重複を確認"
        case .stringReplacer: return "文字列・正規表現・複数ルールで置換"
        case .textCodec: return "Base64・エスケープの変換と復元"
        case .imageResizer: return "画像のサイズ変更・JPEG/PNG保存"
        case .userAgent: return "ブラウザ環境・端末情報の確認とコピー"
        case .colorPalette: return "120色・HEX/RGB・グラデーション・メモ"
        case .comparison: return "テキスト差分・リストの共通と片側のみ"
        }
    }
    var symbol: String {
        switch self {
        case .cidrAnalyzer: return "network"
        case .dnsRecordBuilder: return "server.rack"
        case .unitConverter: return "arrow.left.arrow.right"
        case .percentageCalculator: return "percent"
        case .simpleCalculator: return "plus.forwardslash.minus"
        case .numberCalculator: return "sum"
        case .cronReader: return "calendar.badge.clock"
        case .linuxCommands: return "terminal"
        case .chmodCalculator: return "lock.shield"
        case .directoryTree: return "folder.badge.gearshape"
        case .unixTimeConverter: return "clock.arrow.circlepath"
        case .randomNumberGenerator: return "dice"
        case .pomodoroTimer: return "timer"
        case .timerBoard: return "square.grid.2x2"
        case .meetingTimer: return "person.3"
        case .timeCalculator: return "clock.badge.checkmark"
        case .byteConverter: return "internaldrive"
        case .numberBaseConverter: return "number"
        case .bandwidthCalculator: return "network"
        case .raidCalculator: return "externaldrive.badge.plus"
        case .slaCalculator: return "checkmark.shield"
        case .portNumberFinder: return "network"
        case .httpStatusViewer: return "number.square"
        case .hashGenerator: return "number"
        case .testDataGenerator: return "wand.and.stars"
        case .localMemo: return "note.text"
        case .systemMonitor: return "waveform.path.ecg"
        case .businessDays: return "calendar"
        case .audioCheck: return "speaker.wave.2"
        case .microphoneCheck: return "mic"
        case .csvViewer: return "tablecells"
        case .csvEditor: return "square.and.pencil"
        case .sequentialText: return "list.number"
        case .clipboardFormatter: return "clipboard"
        case .textCleaner: return "sparkles"
        case .lineTools: return "arrow.up.arrow.down"
        case .stringReplacer: return "text.magnifyingglass"
        case .textCodec: return "arrow.left.arrow.right"
        case .imageResizer: return "photo"
        case .userAgent: return "desktopcomputer"
        case .colorPalette: return "paintpalette"
        case .comparison: return "rectangle.split.2x1"
        }
    }
}

extension ToolID {
    var category: ToolCategory {
        switch self {
        case .unitConverter, .percentageCalculator, .simpleCalculator, .numberCalculator: return .calculation
        case .cidrAnalyzer, .dnsRecordBuilder, .cronReader, .linuxCommands, .chmodCalculator, .directoryTree, .unixTimeConverter: return .server
        case .hashGenerator, .testDataGenerator, .localMemo, .csvViewer, .csvEditor, .sequentialText, .clipboardFormatter, .textCleaner, .lineTools, .stringReplacer, .comparison, .textCodec: return .text
        case .randomNumberGenerator, .byteConverter, .numberBaseConverter, .bandwidthCalculator, .raidCalculator, .slaCalculator: return .calculation
        case .colorPalette, .imageResizer: return .design
        case .portNumberFinder, .httpStatusViewer, .systemMonitor, .audioCheck, .microphoneCheck, .userAgent: return .system
        case .businessDays, .pomodoroTimer, .timerBoard, .meetingTimer, .timeCalculator: return .calendar
        }
    }
    func matches(_ query: String) -> Bool {
        let terms = query.split(whereSeparator: { $0.isWhitespace })
        let aliases = self == .testDataGenerator ? " dummy-data-generator uuid-generator text-generator ダミーデータ UUID テキスト生成" : ""
        let searchable = title + " " + subtitle + " " + rawValue + " " + category.rawValue + aliases
        return terms.allSatisfy { searchable.localizedStandardContains(String($0)) }
    }
}
