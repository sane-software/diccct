import XCTest
@testable import SaneDiccctCore

/// Integration checks against a real dict.cc export. Skipped unless the env var
/// `SANEDICCCT_REAL_FILE` points to one, so CI and normal `swift test` runs stay
/// hermetic and never depend on (non-redistributable) dict.cc data. Run with:
///
///     SANEDICCCT_REAL_FILE=/path/to/export.txt swift test
///
final class RealFileIntegrationTests: XCTestCase {
    private func realFilePath() throws -> String {
        guard let path = ProcessInfo.processInfo.environment["SANEDICCCT_REAL_FILE"] else {
            throw XCTSkip("Set SANEDICCCT_REAL_FILE to run the real-file integration test.")
        }
        return path
    }

    func testParsesAndSearchesRealFile() throws {
        let path = try realFilePath()

        let pair = try DictccParser.detectPair(atPath: path)
        XCTAssertTrue(pair.code0 == "DE" || pair.code1 == "DE", "expected a German pair")

        let parseStart = Date()
        let entries = try DictccParser.parseEntries(atPath: path, pair: pair)
        let parseSeconds = Date().timeIntervalSince(parseStart)
        XCTAssertGreaterThan(entries.count, 100_000, "a full export should have many rows")

        let indexStart = Date()
        let index = TranslationIndex(entries: entries)
        let indexSeconds = Date().timeIntervalSince(indexStart)

        let searchStart = Date()
        let results = index.search("Haus", limit: 50)
        let searchSeconds = Date().timeIntervalSince(searchStart)
        XCTAssertFalse(results.isEmpty, "'Haus' should match in a DE-EN export")
        XCTAssertLessThanOrEqual(results.count, 50)

        // Diacritic folding on real data.
        XCTAssertFalse(index.search("grun", limit: 50).isEmpty, "'grun' should find 'grün' forms")

        print(String(format: "[real-file] rows=%d parse=%.2fs index=%.2fs search=%.3fs",
                     entries.count, parseSeconds, indexSeconds, searchSeconds))
    }
}
