import Foundation

/// Independently authored Linux quick reference. Commands are never executed.
public struct CommandReference: Identifiable {
    public let name: String
    public let category: String
    public let summary: String
    public let example: String
    public let options: String
    public let note: String
    public var id: String { name }
    public func matches(_ query: String) -> Bool {
        let text = [name, category, summary, example, options, note].joined(separator: " ")
        return query.split(whereSeparator: { $0.isWhitespace }).allSatisfy { text.localizedStandardContains(String($0)) }
    }
    public static let entries: [CommandReference] = [
        .init(name: "pwd", category: "ファイル", summary: "現在の作業ディレクトリを表示", example: "pwd -P", options: "-L: 論理パス、-P: シンボリックリンク解決後", note: "シェル組込み版と外部コマンドで動作が異なる場合があります。"),
        .init(name: "ls", category: "ファイル", summary: "ファイル一覧を表示", example: "ls -lah /var/log", options: "-l: 詳細、-a: 隠しファイル、-h: 読みやすい容量", note: "GNU coreutils版を想定。"),
        .init(name: "cd", category: "ファイル", summary: "作業ディレクトリを変更", example: "cd /var/log", options: "cd -: 前のディレクトリ、cd: ホーム", note: "シェルの組込みコマンドです。"),
        .init(name: "cp", category: "ファイル", summary: "ファイルやディレクトリをコピー", example: "cp -i source.txt destination.txt", options: "-i: 上書き確認、-r: 再帰コピー、-a: 属性を保持", note: "既存のコピー先を上書きする場合があります。"),
        .init(name: "mv", category: "ファイル", summary: "ファイルを移動・改名", example: "mv -i old.txt new.txt", options: "-i: 上書き確認、-n: 上書きしない", note: "移動先に同名ファイルがある場合は確認してください。"),
        .init(name: "mkdir", category: "ファイル", summary: "ディレクトリを作成", example: "mkdir -p project/src", options: "-p: 親ディレクトリも作成、-m: 権限指定", note: "-pは既存ディレクトリをエラーにしません。"),
        .init(name: "rm", category: "ファイル", summary: "ファイルを削除", example: "rm -i obsolete.txt", options: "-i: 確認、-r: ディレクトリを再帰削除", note: "ゴミ箱を経由しません。対象を確認してから実行してください。"),
        .init(name: "find", category: "検索", summary: "条件に合うファイルを探す", example: "find /var/log -type f -name '*.log'", options: "-type f: 通常ファイル、-name: 名前、-mtime: 更新日", note: "ワイルドカードは引用符で囲みます。"),
        .init(name: "grep", category: "検索", summary: "テキストから一致行を検索", example: "grep -n 'error' application.log", options: "-n: 行番号、-i: 大文字小文字無視、-E: 拡張正規表現、-F: 固定文字列", note: "正規表現と固定文字列を使い分けます。"),
        .init(name: "less", category: "テキスト", summary: "テキストをページ表示", example: "less /var/log/syslog", options: "/: 検索、n: 次の一致、q: 終了", note: "ログの場所はディストリビューションにより異なります。"),
        .init(name: "head", category: "テキスト", summary: "先頭の行を表示", example: "head -n 20 access.log", options: "-n: 行数、-c: バイト数", note: "指定なしでは先頭10行です。"),
        .init(name: "tail", category: "テキスト", summary: "末尾の行を表示・追跡", example: "tail -n 50 -f application.log", options: "-n: 行数、-f: 追跡、-F: 名前を追跡して再試行", note: "追跡はCtrl+Cで停止します。"),
        .init(name: "wc", category: "テキスト", summary: "行数・単語数・バイト数を集計", example: "wc -l access.log", options: "-l: 改行数、-w: 単語数、-c: バイト数、-m: 文字数", note: "末尾に改行のない行は-lに数えられません。"),
        .init(name: "sort", category: "テキスト", summary: "行を並べ替え", example: "sort -n values.txt", options: "-n: 数値、-r: 逆順、-u: 重複除去", note: "並び順はロケールに依存します。"),
        .init(name: "uniq", category: "テキスト", summary: "隣接した重複行をまとめる", example: "sort names.txt | uniq -c", options: "-c: 件数、-d: 重複行のみ、-u: 一度だけの行", note: "離れた重複行はまとめません。"),
        .init(name: "sed", category: "テキスト", summary: "行単位で文字列を変換", example: "sed 's/old/new/g' input.txt", options: "-n: 自動出力抑制、-E: 拡張正規表現", note: "例は標準出力だけに出力します。-iはファイルを書き換えます。"),
        .init(name: "awk", category: "テキスト", summary: "列や条件に基づきテキストを処理", example: "awk '{print $1}' access.log", options: "-F: フィールド区切り、-v: 変数", note: "既定では空白でフィールドを分割します。"),
        .init(name: "ps", category: "プロセス", summary: "プロセスを一覧表示", example: "ps aux", options: "a: 他ユーザー、u: ユーザー形式、x: 端末なしも表示", note: "procps-ngのBSD形式オプションを想定。"),
        .init(name: "top", category: "プロセス", summary: "CPU・メモリ・プロセスを継続表示", example: "top", options: "q: 終了、P: CPU順、M: メモリ順", note: "操作はprocps-ng版を想定。"),
        .init(name: "kill", category: "プロセス", summary: "プロセスへシグナルを送る", example: "kill -TERM 1234", options: "-TERM: 終了要求、-l: シグナル一覧", note: "PIDを確認してください。強制終了では後処理されません。"),
        .init(name: "df", category: "ストレージ", summary: "ファイルシステムの容量を表示", example: "df -h /", options: "-h: 読みやすい容量、-i: inode、-T: 種類", note: "GNU版を想定。"),
        .init(name: "du", category: "ストレージ", summary: "ファイル・ディレクトリの使用量", example: "du -sh /var/log", options: "-s: 合計、-h: 読みやすい容量、-x: 同一FSのみ", note: "dfとは測定対象が異なります。"),
        .init(name: "free", category: "ストレージ", summary: "メモリ使用状況を表示", example: "free -h", options: "-h: 読みやすい容量、-s: 更新間隔（秒）", note: "availableはアプリで利用可能なメモリの推定です。"),
        .init(name: "ip", category: "ネットワーク", summary: "アドレス・経路・リンクを表示", example: "ip -brief address show", options: "address: アドレス、route: 経路、link: リンク", note: "iproute2。変更操作には権限が必要です。"),
        .init(name: "ss", category: "ネットワーク", summary: "ソケットと待受ポートを表示", example: "ss -lnt", options: "-l: 待受、-n: 数値、-t: TCP、-u: UDP、-p: プロセス", note: "他ユーザーのプロセス情報には権限が必要です。"),
        .init(name: "ping", category: "ネットワーク", summary: "ICMPで疎通と応答時間を確認", example: "ping -c 4 example.com", options: "-c: 回数、-W: 応答待ち時間（秒）", note: "iputils版を想定。応答がなくても接続不可とは限りません。"),
        .init(name: "dig", category: "ネットワーク", summary: "DNSへ問い合わせ", example: "dig example.com A", options: "+short: 簡易表示、@server: 問合せ先指定、+trace: 委任追跡", note: "BINDのDNSユーティリティ。通常は別途導入が必要です。"),
        .init(name: "curl", category: "ネットワーク", summary: "URLへリクエスト", example: "curl -I https://example.com", options: "-I: HEAD、-L: リダイレクト追従、-o: 出力先", note: "リクエスト内容は宛先へ送信されます。"),
        .init(name: "ssh", category: "ネットワーク", summary: "暗号化したリモート接続", example: "ssh -p 22 user@server.example", options: "-p: ポート、-i: 秘密鍵ファイル、-L: ローカル転送", note: "初回接続ではホスト鍵を確認します。"),
        .init(name: "scp", category: "ネットワーク", summary: "SSH経由でファイルを転送", example: "scp file.txt user@server.example:/tmp/", options: "-P: ポート、-i: 秘密鍵ファイル、-r: 再帰コピー", note: "OpenSSHの新しい版では既定でSFTPを使用します。"),
        .init(name: "chmod", category: "権限", summary: "ファイル権限を変更", example: "chmod 640 file.txt", options: "u: 所有者、g: グループ、o: その他、+: 追加、-: 削除", note: "対象の権限が変わります。ディレクトリのxは通過権限です。"),
        .init(name: "chown", category: "権限", summary: "所有者・グループを変更", example: "chown user:group file.txt", options: "-R: 再帰、--reference: 参照ファイルと同じにする", note: "所有者変更には通常管理者権限が必要です。"),
        .init(name: "id", category: "権限", summary: "ユーザーと所属グループを確認", example: "id", options: "-u: UID、-g: 主GID、-G: 全GID、-n: 名前", note: "引数にユーザー名も指定できます。"),
        .init(name: "systemctl", category: "サービス", summary: "systemdのサービス状態・操作", example: "systemctl status ssh.service", options: "status: 状態、is-active: 稼働判定、list-units: 一覧", note: "systemd環境専用。ユニット名は環境で異なります。"),
        .init(name: "journalctl", category: "サービス", summary: "systemd journalを表示", example: "journalctl -u ssh.service -n 50", options: "-u: ユニット、-n: 行数、-f: 追跡、-b: 今回の起動", note: "参照権限とログ保存設定に依存します。"),
        .init(name: "crontab", category: "サービス", summary: "ユーザーの定期実行を管理", example: "crontab -l", options: "-l: 表示、-e: 編集、-r: 全削除", note: "-rはユーザーの登録全体を削除します。"),
        .init(name: "uname", category: "システム", summary: "カーネル情報を表示", example: "uname -a", options: "-a: 全体、-r: リリース、-m: マシン名", note: "ディストリビューション名は/etc/os-releaseを参照します。"),
        .init(name: "uptime", category: "システム", summary: "稼働時間と負荷平均を表示", example: "uptime", options: "-p: 読みやすい稼働時間、-s: 起動日時", note: "procps-ng版を想定。負荷平均はCPU使用率ではありません。"),
        .init(name: "tar", category: "アーカイブ", summary: "ファイルをアーカイブ", example: "tar -tf archive.tar", options: "-t: 一覧、-c: 作成、-x: 展開、-f: ファイル指定、-z: gzip", note: "展開前に内容と保存先を確認します。"),
        .init(name: "date", category: "システム", summary: "日時・Unix時刻を表示", example: "date -u '+%Y-%m-%d %H:%M:%S'", options: "-u: UTC、+%s: Unix秒、-d: 指定日時の変換", note: "-dはGNU版。macOSのdateとは異なります。")
    ]
}
