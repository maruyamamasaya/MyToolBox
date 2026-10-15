import Foundation

public enum RandomNumbers {
    public enum GenerationError: LocalizedError {
        case invalidInput
        public var errorDescription: String? { "範囲・個数（1〜100）・桁数（1〜32）を確認してください。" }
    }
    public static func generate<R: RandomNumberGenerator>(minimum: Int = 1, maximum: Int = 100, digits: Int? = nil, startsAtZero: Bool = false, count: Int, using generator: inout R) throws -> [String] {
        guard (1...100).contains(count), minimum <= maximum,
              digits.map({ (1...32).contains($0) }) ?? true else { throw GenerationError.invalidInput }
        return (0..<count).map { _ in
            guard let digits else { return String(Int.random(in: minimum...maximum, using: &generator)) }
            let characters = (0..<digits).map { index in
                String(Int.random(in: (index == 0 && !startsAtZero ? 1 : 0)...9, using: &generator))
            }.joined()
            let trimmed = characters.drop(while: { $0 == "0" })
            return trimmed.isEmpty ? "0" : String(trimmed)
        }
    }
}
