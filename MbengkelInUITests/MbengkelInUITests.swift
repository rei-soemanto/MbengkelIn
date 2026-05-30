//
//  MbengkelInUITests.swift
//  MbengkelInUITests
//

import XCTest

final class MbengkelInUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    @MainActor
    func testReachesLoginOrTabs() throws {
        let app = XCUIApplication()
        app.launch()

        let login = app.buttons["Masuk"]
        let tabs = app.tabBars.firstMatch
        let deadline = Date().addingTimeInterval(12)
        var reached = false
        while Date() < deadline {
            if login.exists || tabs.exists {
                reached = true
                break
            }
            _ = login.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(reached, "Expected either login button or a tab bar")
    }

    @MainActor
    func testLoginScreenElements() throws {
        let app = XCUIApplication()
        app.launch()

        if app.buttons["Masuk"].waitForExistence(timeout: 12) {
            XCTAssertTrue(app.textFields["Email"].exists)
            XCTAssertTrue(app.secureTextFields["Password"].exists)
            XCTAssertTrue(
                app.staticTexts["Daftar"].exists || app.buttons["Daftar"].exists)
        } else {
            throw XCTSkip("Already authenticated — login screen not shown")
        }
    }
}
