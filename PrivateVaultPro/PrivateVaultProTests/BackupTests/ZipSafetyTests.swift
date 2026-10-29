//
//  ZipSafetyTests.swift
//  PrivateVaultProTests
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import XCTest
@testable import PrivateVaultPro

final class ZipSafetyTests: XCTestCase {

    func testRejectsPathTraversalDotDot() {
        let maliciousPaths = [
            "../secret.txt",
            "../../etc/passwd",
            "media/../../../escaped.jpg",
            "..\\windows\\system32\\cmd.exe",
            "folder/..//..//danger.bin"
        ]

        for path in maliciousPaths {
            XCTAssertThrowsError(try ZipSafetyValidator.validateEntryPath(path), "Path \(path) should have been rejected") { error in
                guard let zipErr = error as? ZipSafetyError else {
                    XCTFail("Expected ZipSafetyError")
                    return
                }
                if case .pathTraversalDetected = zipErr {
                    // Passed
                } else {
                    XCTFail("Expected pathTraversalDetected for \(path)")
                }
            }
        }
    }

    func testRejectsAbsolutePaths() {
        let absolutePaths = [
            "/var/mobile/Containers/test.txt",
            "\\Windows\\System32\\calc.exe",
            "C:/sensitive/data.enc",
            "D:\\backups\\item.zip"
        ]

        for path in absolutePaths {
            XCTAssertThrowsError(try ZipSafetyValidator.validateEntryPath(path), "Path \(path) should be rejected")
        }
    }

    func testAllowsSafeRelativePaths() throws {
        let safePaths = [
            "manifest.json",
            "vault_payload.enc",
            "media/photo_01.enc",
            "thumbnails/photo_01.thumb.enc"
        ]

        for path in safePaths {
            XCTAssertNoThrow(try ZipSafetyValidator.validateEntryPath(path))
        }
    }

    func testZipBombLimits() {
        // Exceeding entry count threshold
        XCTAssertThrowsError(try ZipSafetyValidator.validateLimits(entryCount: 60_000, totalBytes: 1024))
        // Exceeding byte size threshold
        XCTAssertThrowsError(try ZipSafetyValidator.validateLimits(entryCount: 10, totalBytes: 25 * 1024 * 1024 * 1024))
        // Normal bounds pass
        XCTAssertNoThrow(try ZipSafetyValidator.validateLimits(entryCount: 500, totalBytes: 1024 * 1024 * 50))
    }
}
