// Explicit verification of ICU progress cancellation; no app settings or user data.
import Foundation
@main struct RegexBudgetProbe {
    static func main() throws {
        var options = StringReplacer.Options(); options.regex = true; options.query = "(a+)+$"
        let start = ProcessInfo.processInfo.systemUptime
        do { _ = try StringReplacer.run(String(repeating: "a", count: 2000) + "!", options: options); throw ToolFailure.message("Expected bounded timeout") }
        catch {
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            guard error.localizedDescription.contains("処理時間上限"), elapsed < 2 else { throw error }
            print(String(format: "Regex progress budget verified: %.3f seconds", elapsed))
        }
    }
}
