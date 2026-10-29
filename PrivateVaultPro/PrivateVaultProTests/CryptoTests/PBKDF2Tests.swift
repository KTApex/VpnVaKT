//
//  PBKDF2Tests.swift
//  PrivateVaultProTests
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import XCTest
import CryptoKit
@testable import PrivateVaultPro

final class PBKDF2Tests: XCTestCase {

    func testSaltGenerationLength() {
        let salt = PBKDF2KeyDerivation.generateSalt(length: 16)
        XCTAssertEqual(salt.count, 16)

        let salt2 = PBKDF2KeyDerivation.generateSalt(length: 32)
        XCTAssertEqual(salt2.count, 32)
        XCTAssertNotEqual(salt, salt2.subdata(in: 0..<16))
    }

    func testPBKDF2DeterministicDerivation() throws {
        let password = "SuperSecurePassword2026!"
        let salt = "StaticSalt123456".data(using: .utf8)!

        let key1 = try PBKDF2KeyDerivation.deriveKey(from: password, salt: salt, iterations: 10_000)
        let key2 = try PBKDF2KeyDerivation.deriveKey(from: password, salt: salt, iterations: 10_000)

        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }

        XCTAssertEqual(data1, data2)
        XCTAssertEqual(data1.count, 32) // 256 bits
    }

    func testEmptyPasswordThrows() {
        let salt = PBKDF2KeyDerivation.generateSalt(length: 16)
        XCTAssertThrowsError(try PBKDF2KeyDerivation.deriveKey(from: "", salt: salt)) { error in
            guard let pbkdfError = error as? PBKDF2Error else {
                XCTFail("Expected PBKDF2Error")
                return
            }
            if case .emptyPassword = pbkdfError {
                // Expected
            } else {
                XCTFail("Expected emptyPassword error")
            }
        }
    }
}
