import Foundation

/// Curated defaults from the reference tools; no network probing is performed.
public struct PortReference: Identifiable {
    public let port: Int
    public let service: String
    public let transport: String
    public let summary: String
    public var id: Int { port }
    public static let popular = [22, 53, 80, 443, 3306, 3389, 5432, 8080]
    public static func search(_ query: String, transport: String = "all") -> [PortReference] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let numeric = !term.isEmpty && term.utf8.allSatisfy { $0 >= 48 && $0 <= 57 }
        return all.filter { item in
            guard transport == "all" || item.transport.split(separator: "/").contains(Substring(transport)) else { return false }
            if numeric { return Int(term) == item.port }
            let aliases = item.summary.contains("データベース") ? " database db" : ""
            return term.isEmpty || "\(item.port) \(item.service) \(item.summary)\(aliases)".localizedStandardContains(term)
        }
    }
    public static let all: [PortReference] = [
        .init(port: 20, service: "FTP Data", transport: "TCP", summary: "FTPのデータ転送"),
        .init(port: 21, service: "FTP", transport: "TCP", summary: "ファイル転送の制御"),
        .init(port: 22, service: "SSH / SFTP", transport: "TCP", summary: "安全なリモート接続・ファイル転送"),
        .init(port: 23, service: "Telnet", transport: "TCP", summary: "暗号化されないリモート接続"),
        .init(port: 25, service: "SMTP", transport: "TCP", summary: "メール送信"),
        .init(port: 53, service: "DNS", transport: "TCP/UDP", summary: "ドメイン名の名前解決"),
        .init(port: 67, service: "DHCP Server", transport: "UDP", summary: "IPアドレスの自動割り当て（サーバー）"),
        .init(port: 68, service: "DHCP Client", transport: "UDP", summary: "IPアドレスの自動割り当て（クライアント）"),
        .init(port: 69, service: "TFTP", transport: "UDP", summary: "簡易ファイル転送"),
        .init(port: 80, service: "HTTP", transport: "TCP", summary: "Webサイト（暗号化なし）"),
        .init(port: 110, service: "POP3", transport: "TCP", summary: "メール受信"),
        .init(port: 123, service: "NTP", transport: "UDP", summary: "時刻同期"),
        .init(port: 143, service: "IMAP", transport: "TCP", summary: "メール受信・同期"),
        .init(port: 161, service: "SNMP", transport: "UDP", summary: "ネットワーク機器の監視"),
        .init(port: 162, service: "SNMP Trap", transport: "UDP", summary: "ネットワーク機器からの通知"),
        .init(port: 179, service: "BGP", transport: "TCP", summary: "ルーター間の経路交換"),
        .init(port: 389, service: "LDAP", transport: "TCP/UDP", summary: "ディレクトリサービス"),
        .init(port: 443, service: "HTTPS", transport: "TCP", summary: "暗号化されたWeb通信"),
        .init(port: 445, service: "SMB", transport: "TCP", summary: "Windowsファイル・プリンター共有"),
        .init(port: 465, service: "SMTPS", transport: "TCP", summary: "暗号化されたメール送信"),
        .init(port: 500, service: "IKE / IPsec", transport: "UDP", summary: "VPN鍵交換"),
        .init(port: 514, service: "Syslog", transport: "UDP", summary: "システムログ転送"),
        .init(port: 587, service: "SMTP Submission", transport: "TCP", summary: "認証付きメール送信"),
        .init(port: 636, service: "LDAPS", transport: "TCP", summary: "暗号化されたLDAP"),
        .init(port: 993, service: "IMAPS", transport: "TCP", summary: "暗号化されたIMAP"),
        .init(port: 995, service: "POP3S", transport: "TCP", summary: "暗号化されたPOP3"),
        .init(port: 1433, service: "Microsoft SQL Server", transport: "TCP", summary: "SQL Serverデータベース"),
        .init(port: 1521, service: "Oracle Database", transport: "TCP", summary: "Oracleデータベース"),
        .init(port: 2049, service: "NFS", transport: "TCP/UDP", summary: "ネットワークファイル共有"),
        .init(port: 2375, service: "Docker", transport: "TCP", summary: "Docker API（暗号化なし）"),
        .init(port: 2376, service: "Docker TLS", transport: "TCP", summary: "Docker API（TLS）"),
        .init(port: 3000, service: "Development Server", transport: "TCP", summary: "開発用Webサーバーでよく使用"),
        .init(port: 3306, service: "MySQL / MariaDB", transport: "TCP", summary: "MySQL系データベース"),
        .init(port: 3389, service: "RDP", transport: "TCP/UDP", summary: "Windowsリモートデスクトップ"),
        .init(port: 5432, service: "PostgreSQL", transport: "TCP", summary: "PostgreSQLデータベース"),
        .init(port: 5672, service: "AMQP / RabbitMQ", transport: "TCP", summary: "メッセージキュー"),
        .init(port: 5900, service: "VNC", transport: "TCP", summary: "リモートデスクトップ"),
        .init(port: 6379, service: "Redis", transport: "TCP", summary: "インメモリデータストア"),
        .init(port: 6443, service: "Kubernetes API", transport: "TCP", summary: "Kubernetes APIサーバー"),
        .init(port: 8080, service: "HTTP Alternate", transport: "TCP", summary: "代替HTTP・プロキシ・開発サーバー"),
        .init(port: 8443, service: "HTTPS Alternate", transport: "TCP", summary: "代替HTTPS"),
        .init(port: 9200, service: "Elasticsearch", transport: "TCP", summary: "検索・分析エンジン"),
        .init(port: 27017, service: "MongoDB", transport: "TCP", summary: "MongoDBデータベース"),
    ]
}

public struct HTTPStatusReference: Identifiable {
    public let code: Int
    public let name: String
    public let summary: String
    public var id: Int { code }
    public var category: Int { code / 100 }
    public var categoryName: String { Self.categoryNames[category] ?? "" }
    public static let categoryNames = [1: "情報", 2: "成功", 3: "リダイレクト", 4: "クライアントエラー", 5: "サーバーエラー"]
    public static func search(_ query: String, category: Int = 0) -> [HTTPStatusReference] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return all.filter { item in
            (category == 0 || item.category == category) &&
            (term.isEmpty || "\(item.code) \(item.name) \(item.summary) \(item.categoryName)".localizedStandardContains(term))
        }
    }
    public static let all: [HTTPStatusReference] = [
        .init(code: 100, name: "Continue", summary: "リクエストを継続できます。"),
        .init(code: 101, name: "Switching Protocols", summary: "プロトコルを切り替えています。"),
        .init(code: 102, name: "Processing", summary: "リクエストを処理中です。"),
        .init(code: 103, name: "Early Hints", summary: "最終レスポンスより前に、読み込みのヒントを返します。"),
        .init(code: 200, name: "OK", summary: "リクエストが正常に成功しました。"),
        .init(code: 201, name: "Created", summary: "リクエストが成功し、新しいリソースが作成されました。"),
        .init(code: 202, name: "Accepted", summary: "リクエストは受理されましたが、処理は完了していません。"),
        .init(code: 204, name: "No Content", summary: "成功しましたが、返すコンテンツはありません。"),
        .init(code: 206, name: "Partial Content", summary: "リソースの一部分を返しました。"),
        .init(code: 300, name: "Multiple Choices", summary: "複数の選択肢があります。"),
        .init(code: 301, name: "Moved Permanently", summary: "リソースは恒久的に移動しました。"),
        .init(code: 302, name: "Found", summary: "リソースは一時的に別の場所にあります。"),
        .init(code: 303, name: "See Other", summary: "別のURLをGETで参照してください。"),
        .init(code: 304, name: "Not Modified", summary: "キャッシュ済みの内容から変更されていません。"),
        .init(code: 307, name: "Temporary Redirect", summary: "メソッドを維持したまま一時的に転送します。"),
        .init(code: 308, name: "Permanent Redirect", summary: "メソッドを維持したまま恒久的に転送します。"),
        .init(code: 400, name: "Bad Request", summary: "構文などに問題があり、リクエストを処理できません。"),
        .init(code: 401, name: "Unauthorized", summary: "認証が必要です。"),
        .init(code: 403, name: "Forbidden", summary: "アクセスする権限がありません。"),
        .init(code: 404, name: "Not Found", summary: "指定されたリソースが見つかりません。"),
        .init(code: 405, name: "Method Not Allowed", summary: "そのHTTPメソッドは許可されていません。"),
        .init(code: 406, name: "Not Acceptable", summary: "要求された形式でレスポンスを返せません。"),
        .init(code: 408, name: "Request Timeout", summary: "リクエストが時間内に完了しませんでした。"),
        .init(code: 409, name: "Conflict", summary: "リソースの現在の状態と競合しています。"),
        .init(code: 410, name: "Gone", summary: "リソースは恒久的に削除されています。"),
        .init(code: 411, name: "Length Required", summary: "Content-Lengthヘッダーが必要です。"),
        .init(code: 412, name: "Precondition Failed", summary: "リクエストの前提条件を満たしていません。"),
        .init(code: 413, name: "Content Too Large", summary: "送信された内容が大きすぎます。"),
        .init(code: 414, name: "URI Too Long", summary: "URIが長すぎます。"),
        .init(code: 415, name: "Unsupported Media Type", summary: "送信されたメディア形式に対応していません。"),
        .init(code: 416, name: "Range Not Satisfiable", summary: "要求されたデータ範囲を返せません。"),
        .init(code: 418, name: "I'm a teapot", summary: "ティーポットなのでコーヒーを淹れられません。"),
        .init(code: 422, name: "Unprocessable Content", summary: "構文は正しいものの、内容を処理できません。"),
        .init(code: 423, name: "Locked", summary: "対象のリソースはロックされています。"),
        .init(code: 424, name: "Failed Dependency", summary: "依存する処理が失敗しました。"),
        .init(code: 425, name: "Too Early", summary: "リクエストを処理するには早すぎます。"),
        .init(code: 426, name: "Upgrade Required", summary: "別のプロトコルへの切り替えが必要です。"),
        .init(code: 428, name: "Precondition Required", summary: "リクエストに前提条件が必要です。"),
        .init(code: 429, name: "Too Many Requests", summary: "短時間にリクエストを送りすぎています。"),
        .init(code: 431, name: "Request Header Fields Too Large", summary: "リクエストヘッダーが大きすぎます。"),
        .init(code: 451, name: "Unavailable For Legal Reasons", summary: "法的な理由により利用できません。"),
        .init(code: 500, name: "Internal Server Error", summary: "サーバー内部で予期しないエラーが発生しました。"),
        .init(code: 501, name: "Not Implemented", summary: "リクエストされた機能に対応していません。"),
        .init(code: 502, name: "Bad Gateway", summary: "上流サーバーから不正な応答を受け取りました。"),
        .init(code: 503, name: "Service Unavailable", summary: "一時的にサービスを利用できません。"),
        .init(code: 504, name: "Gateway Timeout", summary: "上流サーバーから時間内に応答がありません。"),
        .init(code: 505, name: "HTTP Version Not Supported", summary: "そのHTTPバージョンには対応していません。"),
        .init(code: 506, name: "Variant Also Negotiates", summary: "コンテンツネゴシエーションの設定に問題があります。"),
        .init(code: 507, name: "Insufficient Storage", summary: "処理に必要な保存容量が不足しています。"),
        .init(code: 508, name: "Loop Detected", summary: "処理中に無限ループを検出しました。"),
        .init(code: 510, name: "Not Extended", summary: "リクエストを満たすための拡張が不足しています。"),
        .init(code: 511, name: "Network Authentication Required", summary: "ネットワークへの接続認証が必要です。"),
    ]
}
