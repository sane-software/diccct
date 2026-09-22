import XCTest
@testable import DiccctCore

final class SearchHistoryTests: XCTestCase {
    func testUndoRedoAcrossSequentialSearches() {
        var history = SearchHistory()
        history.record("haus")
        history.record("baum")

        XCTAssertEqual(history.current, "baum")
        XCTAssertTrue(history.canUndo)

        XCTAssertEqual(history.undo(), "haus")
        XCTAssertEqual(history.redo(), "baum")
    }

    func testRedoPastNewestClearsField() {
        var history = SearchHistory()
        history.record("haus")

        // Redo past the only/newest entry -> cleared (empty) state.
        XCTAssertEqual(history.redo(), "")
        XCTAssertEqual(history.current, "")
        XCTAssertFalse(history.canRedo)
        // Undo from the cleared state returns to the newest search.
        XCTAssertEqual(history.undo(), "haus")
    }

    func testUndoAtOldestReturnsNil() {
        var history = SearchHistory()
        history.record("haus")
        XCTAssertNil(history.undo()) // nothing older than the only entry
    }

    func testUnchangedSearchDoesNotGrowHistory() {
        var history = SearchHistory()
        history.record("haus")
        history.record("haus") // same as shown -> no-op
        XCTAssertEqual(history.storedEntries, ["haus"])
    }

    func testChangedSearchAfterUndoInsertsInBetween() {
        var history = SearchHistory()
        history.record("haus")
        history.record("baum")
        XCTAssertEqual(history.undo(), "haus") // now positioned on "haus"

        // A changed search here inserts between "haus" and "baum", preserving "baum".
        history.record("hund")
        XCTAssertEqual(history.storedEntries, ["haus", "hund", "baum"])
        XCTAssertEqual(history.current, "hund")
        // Redo reaches the preserved "baum"; undo goes back to "haus".
        XCTAssertEqual(history.redo(), "baum")
        XCTAssertEqual(history.undo(), "hund")
        XCTAssertEqual(history.undo(), "haus")
    }

    func testEmptySubmitMovesToClearedEndWithoutAddingEntry() {
        var history = SearchHistory()
        history.record("haus")
        history.record("baum")
        _ = history.undo() // on "haus"

        history.record("") // empty submit
        XCTAssertEqual(history.storedEntries, ["haus", "baum"]) // unchanged
        XCTAssertEqual(history.current, "") // cleared end
        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(history.undo(), "baum") // back to newest
    }

    func testCapacityEvictsOldestFromFront() {
        var history = SearchHistory(capacity: 3)
        history.record("a")
        history.record("b")
        history.record("c")
        history.record("d") // exceeds capacity 3 -> drop "a"

        XCTAssertEqual(history.storedEntries, ["b", "c", "d"])
        XCTAssertEqual(history.current, "d")
        XCTAssertEqual(history.undo(), "c")
        XCTAssertEqual(history.undo(), "b")
        XCTAssertNil(history.undo()) // "a" was evicted
    }
}
