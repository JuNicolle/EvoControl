import XCTest

/// Not a real test — a harness to capture README screenshots of the demo/preview
/// mode (the Simulator has no Bluetooth radio, so this is the only way to show the
/// connected dashboard without a real stove). Run via `xcodebuild test`, then pull
/// the attached screenshots out of the .xcresult bundle with `xcresulttool`.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureScreenshots() throws {
        let app = XCUIApplication()
        app.launch()

        attach(named: "01-connection", of: app)

        let preview = app.buttons["previewButton"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        preview.tap()
        sleep(1)
        attach(named: "02-dashboard-on", of: app)

        // Turn the (demo) stove off to also show the idle state of the hero control.
        let powerButton = app.buttons["Éteindre le poêle"]
        XCTAssertTrue(powerButton.waitForExistence(timeout: 3))
        powerButton.tap()
        sleep(1)
        attach(named: "03-dashboard-off", of: app)

        app.swipeUp()
        sleep(1)
        attach(named: "04-dashboard-scrolled", of: app)
    }

    private func attach(named name: String, of app: XCUIApplication) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
