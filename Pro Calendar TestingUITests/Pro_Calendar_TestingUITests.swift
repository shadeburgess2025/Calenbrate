//
//  Pro_Calendar_TestingUITests.swift
//  Pro Calendar TestingUITests
//
//  Created by Shade Burgess on 10/23/26.
//

import XCTest // interface testing and performance measurements

/// contains app launch and launch performance tests
final class Pro_Calendar_TestingUITests: XCTestCase {

    // setUpWithError() function
    /// a throwing void function that configures interface tests to stop after a failure
    override func setUpWithError() throws {

        // stops the test immediately if a check fails
        continueAfterFailure = false

    }

    // tearDownWithError() function
    /// an empty throwing void function reserved for cleanup after each interface test
    override func tearDownWithError() throws {
    }

    // testExample() function
    /// a throwing test function that launches the app
    @MainActor
    func testExample() throws {
        // creates and launches the app for the interface test
        let app = XCUIApplication()
        app.launch()

    }

    // testLaunchPerformance() function
    /// a throwing test function that measures the time needed to launch the app
    @MainActor
    func testLaunchPerformance() throws {
        // measures how long the app takes to launch
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
