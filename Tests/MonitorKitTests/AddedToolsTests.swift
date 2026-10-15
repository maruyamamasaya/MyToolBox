import XCTest
@testable import MonitorKit

final class AddedToolsTests: XCTestCase {
    func testHashKnownVectorsAndEncodings() throws {
        let vectors: [(TextHash.Algorithm, String, String)] = [
            (.sha1, "da39a3ee5e6b4b0d3255bfef95601890afd80709", "a9993e364706816aba3e25717850c26c9cd0d89d"),
            (.sha256, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
            (.sha384, "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b", "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7"),
            (.sha512, "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e", "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f")]
        for (algorithm, empty, abc) in vectors {
            XCTAssertEqual(try TextHash.generate("", algorithm: algorithm, base64: false), empty)
            XCTAssertEqual(try TextHash.generate("abc", algorithm: algorithm, base64: false), abc)
            let bytes = try XCTUnwrap(Data(base64Encoded: TextHash.generate("abc", algorithm: algorithm, base64: true)))
            XCTAssertEqual(bytes.map { String(format: "%02x", $0) }.joined(), abc)
        }
        XCTAssertNotEqual(try TextHash.generate("日本語😀", algorithm: .sha256, base64: false), try TextHash.generate("日本語😀\n", algorithm: .sha256, base64: false))
        XCTAssertNoThrow(try TextHash.generate(String(repeating: "a", count: 1_048_576), algorithm: .sha256, base64: false))
        XCTAssertThrowsError(try TextHash.generate(String(repeating: "a", count: 1_048_577), algorithm: .sha256, base64: false))
    }
    func testUUIDVersionVariantAndBounds() throws {
        let values = try TestDataGenerator.uuids(count: 100)
        XCTAssertEqual(Set(values).count, 100)
        for value in values {
            XCTAssertNotNil(UUID(uuidString: value)); XCTAssertEqual(value.count, 36)
            let chars = Array(value); XCTAssertEqual(chars[14], "4"); XCTAssertTrue("89ab".contains(chars[19]))
            XCTAssertEqual(value, value.lowercased())
        }
        XCTAssertEqual(try TestDataGenerator.uuids(count: 1).count, 1)
        for count in [0, 101, Int.max] { XCTAssertThrowsError(try TestDataGenerator.uuids(count: count)) }
    }
    func testTextKindsCountsAndSeparators() throws {
        for kind in TestDataGenerator.Kind.allCases {
            for separator in ["\n", ",", " ", "\t"] {
                let text = try TestDataGenerator.text(kind: kind, length: 53, count: 3, separator: separator)
                // Exact total length also covers structured values being padded/truncated.
                XCTAssertEqual(text.count, 161)
                XCTAssertEqual(Array(text)[53], Character(separator))
            }
        }
        let digits = try TestDataGenerator.text(kind: .number, length: 1000, count: 1, separator: "\n")
        XCTAssertTrue(digits.allSatisfy { $0.isASCII && $0.isNumber })
        let alpha = try TestDataGenerator.text(kind: .alpha, length: 1000, count: 1, separator: "\n")
        XCTAssertTrue(alpha.allSatisfy { $0.isASCII && $0.isLetter })
        for (length, count) in [(0,1),(10001,1),(1,0),(1,1001),(10000,101),(Int.max,Int.max)] {
            XCTAssertThrowsError(try TestDataGenerator.text(kind: .ja, length: length, count: count, separator: "\n"))
        }
        XCTAssertEqual(try TestDataGenerator.text(kind: .ja, length: 10000, count: 100, separator: "\n").count, 1_000_099)
    }
    func testSentencesAndCSV() throws {
        for language in ["ja", "en", "mixed"] { for length in 0...2 {
            let text = try TestDataGenerator.sentences(count: 10, length: length, language: language)
            XCTAssertEqual(text.components(separatedBy: "\n").count, 10)
            if language == "mixed" { XCTAssertTrue(text.contains("[")) }
        } }
        XCTAssertThrowsError(try TestDataGenerator.sentences(count: 11, length: 0, language: "ja"))
        let columns: [TestDataGenerator.Column] = [.init("a,\"b\n日本", .text), .init(" ", .number)]
        let parsed = try CSVDocument.parse(TestDataGenerator.csv(columns: columns, count: 10))
        XCTAssertEqual(parsed[0], ["a,\"b\n日本", "column_2"]); XCTAssertEqual(parsed.count, 11)
        XCTAssertEqual(parsed[10][1], "10"); XCTAssertTrue(parsed[1][0].contains(","))
        let full = try CSVDocument.parse(TestDataGenerator.csv(columns: TestDataGenerator.defaultColumns, count: 10))
        XCTAssertEqual(full.count, 11); XCTAssertTrue(full.allSatisfy { $0.count == 10 })
        for row in full.dropFirst() {
            XCTAssertTrue(row[2].hasSuffix("@example.com")); XCTAssertTrue(("2024-01-01"..."2026-12-31").contains(row[4]))
            XCTAssertTrue(["true","false"].contains(row[5])); XCTAssertTrue((100...100000).contains(Int(row[7])!))
        }
        XCTAssertThrowsError(try TestDataGenerator.csv(columns: [], count: 1))
        XCTAssertThrowsError(try TestDataGenerator.csv(columns: columns, count: 11))
        XCTAssertThrowsError(try TestDataGenerator.csv(columns: [.init(String(repeating: "x", count: 1025), .text)], count: 1))
    }
    func testTextCancellation() async {
        let task = Task { try TestDataGenerator.text(kind: .ja, length: 10000, count: 100, separator: "\n") }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled generation returned output") } catch { XCTAssertTrue(error is CancellationError) }
    }
    func testMemoJSONInterchangeAndHistory() throws {
        var note = LocalMemoNote(now: Date(timeIntervalSince1970: 1000)); note.title = " 日本語😀 "; note.content = "a\n\"quoted\""
        XCTAssertEqual(try LocalMemoArchive.importNotes(LocalMemoArchive.backup([note])), [note])
        XCTAssertEqual(try LocalMemoArchive.importNotes(JSONEncoder().encode([note])), [note])
        XCTAssertEqual(try LocalMemoArchive.importNotes(Data(#"{"notes":[]}"#.utf8)), [])
        var archive = LocalMemoArchive(); archive.notes = [note]
        for i in 0..<7 { archive.snapshot(now: Date(timeIntervalSince1970: Double(i))); archive.notes[0].content = String(i) }
        XCTAssertEqual(archive.history.count, 5); XCTAssertEqual(archive.history[0].notes[0].content, "5")
        XCTAssertEqual(try JSONDecoder().decode(LocalMemoArchive.self, from: JSONEncoder().encode(archive)).notes, archive.notes)
        var blank = note; blank.title = " \n"; XCTAssertEqual(blank.displayTitle, "無題のメモ")
    }
    func testMemoRejectsDamagedData() throws {
        let note = LocalMemoNote()
        XCTAssertThrowsError(try LocalMemoArchive.importNotes(JSONEncoder().encode([note,note])))
        var bad = note; bad.createdAt = "not-a-date"
        XCTAssertThrowsError(try LocalMemoArchive.importNotes(JSONEncoder().encode([bad])))
        for json in ["{", #"{"notes":[{"id":"x"}]}"#, #"{"notes":"wrong"}"#] {
            XCTAssertThrowsError(try LocalMemoArchive.importNotes(Data(json.utf8)))
        }
        XCTAssertThrowsError(try LocalMemoArchive.importNotes(Data(repeating: 32, count: 20 * 1024 * 1024 + 1)))
    }
    func testReferenceDataAndPortSearch() {
        XCTAssertEqual(PortReference.all.count, 43); XCTAssertEqual(Set(PortReference.all.map(\.id)).count, 43)
        XCTAssertEqual(PortReference.all.map(\.port), PortReference.all.map(\.port).sorted())
        XCTAssertEqual(PortReference.search(" 080 ").map(\.port), [80])
        XCTAssertEqual(PortReference.search("https").map(\.port), [443,8443])
        XCTAssertTrue(PortReference.search("database").contains { $0.port == 5432 })
        XCTAssertEqual(PortReference.search("53", transport: "TCP").map(\.port), [53])
        XCTAssertEqual(PortReference.search("53", transport: "UDP").map(\.port), [53])
        XCTAssertTrue(PortReference.search("443", transport: "UDP").isEmpty)
        for value in ["65536", String(repeating: "9", count: 100), "no-such-service"] { XCTAssertTrue(PortReference.search(value).isEmpty) }
        XCTAssertEqual(HTTPStatusReference.all.count, 52); XCTAssertEqual(Set(HTTPStatusReference.all.map(\.id)).count, 52)
        XCTAssertEqual(HTTPStatusReference.search("not found").map(\.code), [404])
        XCTAssertTrue(HTTPStatusReference.search("認証").contains { $0.code == 401 })
        XCTAssertTrue(HTTPStatusReference.search("404", category: 5).isEmpty)
        for category in 1...5 { XCTAssertTrue(HTTPStatusReference.search("", category: category).allSatisfy { $0.category == category }) }
    }
}
