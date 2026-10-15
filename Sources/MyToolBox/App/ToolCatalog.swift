/// Installed tools only; each route has a native implementation.
enum ToolID: String, CaseIterable, Identifiable {
    case systemMonitor, businessDays, audioCheck, microphoneCheck, csvViewer, csvEditor, sequentialText, clipboardFormatter, textCleaner, lineTools, stringReplacer, comparison
    var id: String { rawValue }
    var title: String {
        switch self {
        case .systemMonitor: return "システムモニター"
        case .businessDays: return "営業日計算"
        case .audioCheck: return "オーディオチェック"
        case .microphoneCheck: return "マイクチェック"
        case .csvViewer: return "CSVビューワー"
        case .csvEditor: return "CSVエディター"
        case .sequentialText: return "連番テキスト生成"
        case .clipboardFormatter: return "クリップボード整形"
        case .textCleaner: return "テキストクリーナー"
        case .lineTools: return "行ツール"
        case .stringReplacer: return "検索・置換"
        case .comparison: return "比較ツール"
        }
    }
    var subtitle: String {
        switch self {
        case .systemMonitor: return "CPU・メモリ・通信・温度を確認"
        case .businessDays: return "土日・祝日を除いた営業日を計算"
        case .audioCheck: return "左右のスピーカーと出力装置を確認"
        case .microphoneCheck: return "入力レベル・10秒録音で声を確認"
        case .csvViewer: return "CSVを表で表示・検索・並べ替え"
        case .csvEditor: return "セル・行・列を編集してローカル保存"
        case .sequentialText: return "各行に連番・前後の文字を追加"
        case .clipboardFormatter: return "表整形・リスト変換・JSONやSQL形式へ"
        case .textCleaner: return "不可視文字・空行・箇条書きを整理"
        case .lineTools: return "並べ替え・行抽出・重複を確認"
        case .stringReplacer: return "文字列・正規表現・複数ルールで置換"
        case .comparison: return "テキスト差分・リストの共通と片側のみ"
        }
    }
    var symbol: String {
        switch self {
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
        case .comparison: return "rectangle.split.2x1"
        }
    }
}
