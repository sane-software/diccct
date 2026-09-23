import XCTest
@testable import SaneDictCcDictionaryCore

final class HTMLEntitiesTests: XCTestCase {
    func testDecodesDecimalEntity() {
        XCTAssertEqual(HTMLEntities.decode("&#945;-Keratin"), "α-Keratin")
    }

    func testDecodesHexEntity() {
        XCTAssertEqual(HTMLEntities.decode("&#x3B1;-Keratin"), "α-Keratin")
    }

    func testDecodesNamedEntities() {
        XCTAssertEqual(HTMLEntities.decode("Tom &amp; Jerry"), "Tom & Jerry")
    }

    func testLeavesPlainTextUntouched() {
        XCTAssertEqual(HTMLEntities.decode("keratin"), "keratin")
    }

    func testLeavesLoneAmpersandUntouched() {
        XCTAssertEqual(HTMLEntities.decode("fish & chips shop"), "fish & chips shop")
    }
}

final class LanguagePairTests: XCTestCase {
    func testGermanGoesOnTheRight() {
        // Header order DE-EN: column 0 is German, column 1 is English.
        let pair = LanguagePair(code0: "DE", code1: "EN")
        XCTAssertEqual(pair.label, "EN<->DE")
        XCTAssertEqual(pair.leftColumnIndex, 1)  // English (other) on the left
        XCTAssertEqual(pair.rightColumnIndex, 0) // German on the right
    }

    func testGermanGoesOnTheRightRegardlessOfHeaderDirection() {
        let pair = LanguagePair(code0: "EN", code1: "DE")
        XCTAssertEqual(pair.label, "EN<->DE")
        XCTAssertEqual(pair.leftColumnIndex, 0)  // English on the left
        XCTAssertEqual(pair.rightColumnIndex, 1) // German on the right
    }

    func testIdentityIsDirectionIndependent() {
        XCTAssertEqual(LanguagePair(code0: "DE", code1: "EN").id,
                       LanguagePair(code0: "EN", code1: "DE").id)
        XCTAssertEqual(LanguagePair(code0: "DE", code1: "EN").canonicalFileName, "de-en.txt")
    }

    func testFallbackToHeaderOrderWithoutGerman() {
        let pair = LanguagePair(code0: "EN", code1: "FR")
        XCTAssertEqual(pair.label, "EN<->FR")
        XCTAssertEqual(pair.leftColumnIndex, 0)
        XCTAssertEqual(pair.rightColumnIndex, 1)
    }
}

final class DictccParserTests: XCTestCase {
    func testDetectPairFromHeader() throws {
        let header = "# DE-EN vocabulary database\tcompiled by dict.cc\n# Date\t2026\n"
        let pair = try DictccParser.detectPair(inHeaderText: header)
        XCTAssertEqual(pair.code0, "DE")
        XCTAssertEqual(pair.code1, "EN")
    }

    func testMissingHeaderThrows() {
        XCTAssertThrowsError(try DictccParser.detectPair(inHeaderText: "just some text\n")) { error in
            XCTAssertEqual(error as? DictccParser.ParseError, .missingHeader)
        }
    }

    func testParsesEntriesWithDisplayArrangement() {
        // German TAB English TAB wordtype TAB subject
        let contents = """
        # DE-EN vocabulary database\tcompiled by dict.cc
        Keratin {n}\tkeratin\tnoun\t[biochem.]
        grün\tgreen\tadj\t
        &#945;-Keratin {n}\t&#945;-keratin\tnoun\t[biochem.]
        """
        let pair = LanguagePair(code0: "DE", code1: "EN")
        let entries = DictccParser.parseEntries(fromContents: contents, pair: pair)

        XCTAssertEqual(entries.count, 3)
        // English on the left, German on the right.
        XCTAssertEqual(entries[0].left, "keratin")
        XCTAssertEqual(entries[0].right, "Keratin {n}")
        XCTAssertEqual(entries[0].wordType, "noun")
        XCTAssertEqual(entries[0].subject, "[biochem.]")
        // Entities decoded.
        XCTAssertEqual(entries[2].left, "α-keratin")
        XCTAssertEqual(entries[2].right, "α-Keratin {n}")
    }
}

final class TranslationIndexTests: XCTestCase {
    private func makeIndex() -> TranslationIndex {
        let entries = [
            TranslationEntry(id: 0, left: "green", right: "grün"),
            TranslationEntry(id: 1, left: "greenhouse", right: "Gewächshaus"),
            TranslationEntry(id: 2, left: "evergreen", right: "immergrün"),
            TranslationEntry(id: 3, left: "house", right: "Haus"),
        ]
        return TranslationIndex(entries: entries)
    }

    func testExactBeforePrefixBeforeContains() {
        let results = makeIndex().search("green", limit: 50)
        XCTAssertEqual(results.map(\.left), ["green", "greenhouse", "evergreen"])
    }

    func testMatchesEitherLanguage() {
        // Searching a German term returns the row even though we query the right side.
        let results = makeIndex().search("Haus", limit: 50)
        XCTAssertEqual(Set(results.map(\.left)), ["greenhouse", "house"])
    }

    func testDiacriticInsensitive() {
        // "grun" (no umlaut) must find "grün".
        let results = makeIndex().search("grun", limit: 50)
        XCTAssertTrue(results.contains { $0.left == "green" })
    }

    func testCaseInsensitive() {
        XCTAssertFalse(makeIndex().search("GREEN", limit: 50).isEmpty)
    }

    func testLimitIsRespected() {
        XCTAssertEqual(makeIndex().search("green", limit: 2).count, 2)
    }

    func testEmptyQueryReturnsNothing() {
        XCTAssertTrue(makeIndex().search("   ", limit: 50).isEmpty)
    }
}

final class DataDirectoryTests: XCTestCase {
    private func makeTempDir() throws -> DataDirectory {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SaneDictCcDictionaryTests-\(UUID().uuidString)", isDirectory: true)
        let dir = DataDirectory(url: tmp)
        try dir.ensureExists()
        return dir
    }

    func testImportValidFileUsesCanonicalNameAndAppears() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir.url) }

        let source = dir.url.appendingPathComponent("random-download-name.txt")
        try "# DE-EN vocabulary database\tby dict.cc\nKeratin\tkeratin\tnoun\t\n"
            .write(to: source, atomically: true, encoding: .utf8)

        let pair = try dir.importFile(from: source)
        XCTAssertEqual(pair.canonicalFileName, "de-en.txt")

        let available = dir.availableDatasets()
        XCTAssertTrue(available.contains { $0.pair.label == "EN<->DE" })
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: dir.url.appendingPathComponent("de-en.txt").path))
    }

    func testImportInvalidFileThrows() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir.url) }

        let source = dir.url.appendingPathComponent("not-a-dict.txt")
        try "hello world\n".write(to: source, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try dir.importFile(from: source)) { error in
            XCTAssertEqual(error as? DataDirectory.ImportError, .notADictccFile)
        }
    }
}
