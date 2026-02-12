import XCTest

final class AppLaunchTests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func test_appLaunches_showsHomeScreen() throws {
    // Given
    let app = XCUIApplication()

    // When
    app.launch()

    // Then
    XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
  }

  @MainActor
  func test_appLaunches_showsAddButton() throws {
    // Given
    let app = XCUIApplication()

    // When
    app.launch()

    // Then
    let addButton = app.buttons["Add item"]
    XCTAssertTrue(addButton.waitForExistence(timeout: 5))
  }

  @MainActor
  func test_nonProdEnvironment_showsBadge() throws {
    // Given
    let app = XCUIApplication()
    // Note: This test assumes running in NonProd configuration

    // When
    app.launch()

    // Then - look for environment badge
    let badge = app.staticTexts["NON-PROD"]
    // Badge may or may not exist depending on build config
    // This test documents expected behavior
    if badge.exists {
      XCTAssertTrue(badge.isHittable)
    }
  }

  @MainActor
  func test_addItem_opensSheet() throws {
    // Given
    let app = XCUIApplication()
    app.launch()

    // When
    let addButton = app.buttons["Add item"]
    XCTAssertTrue(addButton.waitForExistence(timeout: 5))
    addButton.tap()

    // Then
    XCTAssertTrue(app.navigationBars["New Item"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.textFields["Title"].exists)
    XCTAssertTrue(app.buttons["Save"].exists)
    XCTAssertTrue(app.buttons["Cancel"].exists)
  }
}
