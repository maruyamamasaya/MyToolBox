// Read-only observation of the installed app. Never changes sleep, login, or app settings.
import AppKit
import Foundation

final class LongRunMonitor {
    let folder: URL
    let started = Date()
    let duration: TimeInterval
    var samples = 0
    var events = 0
    var restarts = 0
    var missing = 0
    var previousPID: Int32?
    var previousCPU: Double?
    var previousDate: Date?
    var cpu: [Double] = []
    var rss: [Double] = []
    var gaps = 0
    var tokens: [NSObjectProtocol] = []
    let iso = ISO8601DateFormatter()
    init(folder: URL, duration: TimeInterval) { self.folder = folder; self.duration = duration }
    func run(_ path: String, _ args: [String]) -> String? {
        let process = Process(); process.executableURL = URL(fileURLWithPath: path); process.arguments = args
        let out = Pipe(); process.standardOutput = out; process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        return process.terminationStatus == 0 ? String(data: data, encoding: .utf8) : nil
    }
    func append(_ name: String, _ value: [String: Any]) {
        do {
            let file = folder.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: file.path) { FileManager.default.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600]) }
            let handle = try FileHandle(forWritingTo: file); defer { try? handle.close() }
            try handle.seekToEnd(); var data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]); data.append(10); try handle.write(contentsOf: data)
        } catch { fputs("Observation write failed: \(error)\n", stderr) }
    }
    func lastAppLog() -> [String: Any]? {
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/MyToolBox/Logs")
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil),
              let file = files.filter({ $0.lastPathComponent.hasPrefix("monitor-") && $0.pathExtension == "jsonl" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).last,
              let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        try? handle.seek(toOffset: size > 131072 ? size - 131072 : 0)
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n").reversed() {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any], let snapshot = object["snapshot"] as? [String: Any] else { continue }
            var result: [String: Any] = ["session": object["session"] ?? NSNull(), "date": snapshot["date"] ?? NSNull(), "uptime": snapshot["uptime"] ?? NSNull()]
            if let readings = snapshot["readings"] as? [[String: Any]] {
                for reading in readings where ["network", "storage"].contains(reading["id"] as? String ?? "") {
                    guard let metrics = reading["metrics"] as? [String: Any] else { continue }
                    result[reading["id"] as! String] = metrics.filter { ["受信速度", "送信速度", "読込速度", "書込速度"].contains($0.key) }
                }
            }
            return result
        }; return nil
    }
    func seconds(_ value: String) -> Double? {
        let parts = value.split(separator: ":"); var result = 0.0
        for part in parts { guard let n = Double(part) else { return nil }; result = result * 60 + n }
        return result
    }
    func event(_ kind: String) {
        events += 1
        append("power.jsonl", ["kind": kind, "date": iso.string(from: Date()), "uptime": ProcessInfo.processInfo.systemUptime, "appLog": lastAppLog() ?? ["unavailable": true]])
        if kind == "didWake" {
            for offset in [0, 1, 2, 5, 10, 20, 30, 60] {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(offset)) { [self] in sample(reason: "afterWake-\(offset)s") }
            }
        }
    }
    func sample(reason: String = "periodic") {
        let now = Date(), elapsed = now.timeIntervalSince(started)
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "local.MyToolBox").filter { $0.executableURL?.path == "/Applications/MyToolBox.app/Contents/MacOS/MyToolBox" }
        var row: [String: Any] = ["date": iso.string(from: now), "elapsed": elapsed, "uptime": ProcessInfo.processInfo.systemUptime, "reason": reason, "instances": apps.count]
        samples += 1
        if let app = apps.first {
            let pid = app.processIdentifier; row["pid"] = pid; row["appActive"] = app.isActive; row["appHidden"] = app.isHidden
            if let old = previousPID, old != pid { restarts += 1 }
            if let output = run("/bin/ps", ["-p", String(pid), "-o", "%cpu=,rss=,time=,state="]) {
                let parts = output.split(whereSeparator: \.isWhitespace).map(String.init)
                if parts.count >= 4, let memory = Double(parts[1]), let total = seconds(parts[2]) {
                    row["psCPUPercent"] = Double(parts[0]) ?? NSNull(); row["rssMiB"] = memory / 1024; row["cpuSeconds"] = total; row["processState"] = parts[3]
                    rss.append(memory / 1024)
                    if previousPID == pid, let oldCPU = previousCPU, let oldDate = previousDate {
                        let dt = now.timeIntervalSince(oldDate)
                        if dt > 0 && dt <= 180 && total >= oldCPU { let percent = 100 * (total - oldCPU) / dt; row["intervalCPUPercent"] = percent; cpu.append(percent) }
                        else if dt > 180 { gaps += 1; row["observationGapSeconds"] = dt }
                    }
                    previousCPU = total
                } else { row["resourceReadError"] = true }
            } else { row["resourceReadError"] = true }
            previousPID = pid
        } else { missing += 1; row["appMissing"] = true }
        previousDate = now
        row["appLog"] = lastAppLog() ?? ["unavailable": true]
        append("samples.jsonl", row)
        var status: [String: Any] = ["state": elapsed >= duration ? "complete" : "running", "started": iso.string(from: started), "updated": iso.string(from: now), "targetSeconds": duration, "elapsed": elapsed, "samples": samples, "powerEvents": events, "appRestarts": restarts, "missingSamples": missing, "observationGaps": gaps, "meanCPUPercent": cpu.isEmpty ? NSNull() : cpu.reduce(0,+) / Double(cpu.count), "maxRSSMiB": rss.max() ?? NSNull()]
        status["note"] = "Wall-clock observation; sleep gaps, restarts, UI usage, and missing values must be evaluated separately. Completion alone is not a pass."
        do { try JSONSerialization.data(withJSONObject: status, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("status.json"), options: .atomic) } catch { fputs("Status write failed: \(error)\n", stderr) }
        if elapsed >= duration { exit(0) }
    }
    func start() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let nc = NSWorkspace.shared.notificationCenter
        for (name, kind) in [(NSWorkspace.willSleepNotification, "willSleep"), (NSWorkspace.didWakeNotification, "didWake")] {
            tokens.append(nc.addObserver(forName: name, object: nil, queue: .main) { [self] _ in event(kind) })
        }
        event("observerStarted"); sample(reason: "start")
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [self] _ in sample() }
    }
}
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
let directory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/long-run-check"
let observer = LongRunMonitor(folder: URL(fileURLWithPath: directory), duration: 8 * 3600)
try observer.start()
RunLoop.main.run()
