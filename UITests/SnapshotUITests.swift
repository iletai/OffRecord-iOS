import XCTest

/// App Store screenshots (`bundle exec fastlane screenshots`); devices/languages in fastlane/Snapfile.
/// Not MainActor: default isolation would change the XCTestCase inits, which are nonisolated.
final nonisolated class SnapshotUITests: XCTestCase {
    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-demoSeed"]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        snapshot("01-library")

        app.staticTexts["Intake, week 1"].tap()
        snapshot("02-note")
        app.segmentedControls.buttons["Transcript"].tap()
        snapshot("03-transcript")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["Settings"].tap()
        snapshot("04-settings")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.staticTexts["Intake, week 1"].tap()
        app.buttons["Share or export"].tap()
        snapshot("05-export")
    }
}
