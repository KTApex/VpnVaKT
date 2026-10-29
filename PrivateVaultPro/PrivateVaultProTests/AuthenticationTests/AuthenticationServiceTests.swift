//
//  AuthenticationServiceTests.swift
//  PrivateVaultProTests
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import XCTest
@testable import PrivateVaultPro

final class AuthenticationServiceTests: XCTestCase {
    var authService: AuthenticationService!
    var mockKeychain: MockKeychainService!

    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychainService()
        authService = AuthenticationService(keychainService: mockKeychain)
    }

    func testPinSetupAndAuthentication() throws {
        XCTAssertFalse(authService.hasConfiguredPIN)

        try authService.setupPIN("1234")
        XCTAssertTrue(authService.hasConfiguredPIN)
        XCTAssertTrue(authService.isUnlocked)

        authService.lock()
        XCTAssertFalse(authService.isUnlocked)

        // Wrong PIN
        XCTAssertFalse(authService.authenticateWithPIN("9999"))
        XCTAssertFalse(authService.isUnlocked)

        // Correct PIN
        XCTAssertTrue(authService.authenticateWithPIN("1234"))
        XCTAssertTrue(authService.isUnlocked)
    }

    func testChangePin() throws {
        try authService.setupPIN("1234")

        // Fail with wrong old PIN
        XCTAssertThrowsError(try authService.changePIN(oldPIN: "0000", newPIN: "5678"))

        // Succeed with correct old PIN
        let changed = try authService.changePIN(oldPIN: "1234", newPIN: "5678")
        XCTAssertTrue(changed)

        authService.lock()
        XCTAssertFalse(authService.authenticateWithPIN("1234"))
        XCTAssertTrue(authService.authenticateWithPIN("5678"))
    }

    func testLockoutAfterConsecutiveFailures() throws {
        try authService.setupPIN("1234")
        authService.lock()

        // 5 consecutive failures
        for _ in 0..<5 {
            _ = authService.authenticateWithPIN("0000")
        }

        // Even correct PIN fails during lockout period
        XCTAssertFalse(authService.authenticateWithPIN("1234"))

        // Reset lockout
        authService.resetFailedAttempts()
        XCTAssertTrue(authService.authenticateWithPIN("1234"))
    }

    func testAutoLockTimeoutCalculation() throws {
        try authService.setupPIN("1234")
        XCTAssertTrue(authService.isUnlocked)

        // Immediate lock
        XCTAssertTrue(authService.shouldAutoLock(timeout: .immediate))

        // Never lock
        XCTAssertFalse(authService.shouldAutoLock(timeout: .never))
    }
}
