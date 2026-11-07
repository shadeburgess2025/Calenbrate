//
//  Pro_Calendar_TestingUITestsLaunchTests.swift
//  Pro Calendar TestingUITests
//
//  Created by Shade Burgess on 10/23/26.
//

import XCTest // interface testing and performance measurements

/// checks the app launch screen across supported interface configurations
final class Pro_Calendar_TestingUITestsLaunchTests: XCTestCase {

    // runs the launch test for each supported interface configuration
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    // setUpWithError() function
    /// a throwing void function that configures interface tests to stop after a failure
    override func setUpWithError() throws {
        // stops the test immediately if a check fails
        continueAfterFailure = false
    }

    // testLaunch() function
    /// a throwing test function that launches the app and saves a screenshot of its initial screen
    @MainActor
    func testLaunch() throws {
        // creates and launches the app
        let app = XCUIApplication()
        app.launch()


        // takes a screenshot and keeps it with the test results
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
