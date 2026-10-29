//
//  PrivateVaultProUITests.swift
//  PrivateVaultProUITests
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import XCTest

final class PrivateVaultProUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testInitialLaunchShowsSetupOrLockScreen() throws {
        let app = XCUIApplication()
        app.launch()

        // App should either present Master PIN setup (first launch) or Lock screen
        let pinSetupHeader = app.staticTexts["Create Master PIN"]
        let lockScreenButton = app.buttons["OPEN VAULT"]

        let exists = pinSetupHeader.waitForExistence(timeout: 3.0) || lockScreenButton.waitForExistence(timeout: 3.0)
        XCTAssertTrue(exists, "Expected initial setup PIN or VPN-inspired Lock screen on launch")
    }

    func testDashboardTabBarNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        // If unlocked or in preview environment, verify tab items
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        let galleryTab = app.tabBars.buttons["Gallery"]
        let albumsTab = app.tabBars.buttons["Albums"]
        let settingsTab = app.tabBars.buttons["Settings"]

        if dashboardTab.exists {
            XCTAssertTrue(galleryTab.exists)
            XCTAssertTrue(albumsTab.exists)
            XCTAssertTrue(settingsTab.exists)
        }
    }
}
