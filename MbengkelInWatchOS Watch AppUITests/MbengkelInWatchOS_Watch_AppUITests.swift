//
//  MbengkelInWatchOS_Watch_AppUITests.swift
//  MbengkelInWatchOS Watch AppUITests
//

import XCTest

final class MbengkelInWatchOS_Watch_AppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWatchLaunchesToEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        let predicate = NSPredicate(
            format: "label CONTAINS %@", "Tidak ada pesanan sedang berjalan")
        let emptyState = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 20),
            "Expected the watch empty-state copy to appear")
    }
}
