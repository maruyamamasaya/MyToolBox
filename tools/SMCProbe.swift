import Foundation
@main struct SMCProbe {
    static func main() {
        let reader: SMCReader
        do { reader = try SMCReader() }
        catch { fputs("SMC取得不可: \(error)\n", stderr); exit(1) }
        let keys = ["FNum", "F0Ac", "F1Ac", "Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b", "Tg05", "Tg0D", "Tg0L", "Tg0T"]
        for key in keys {
            do { let value = try reader.read(key); print("\(key)\t\(value.type)\t\(value.value)") }
            catch { print("\(key)\t取得不可\t\(error)") }
        }
    }
}
