//
//  CryptoServiceTests.swift
//  PrivateVaultProTests
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import XCTest
import CryptoKit
@testable import PrivateVaultPro

final class CryptoServiceTests: XCTestCase {
    var cryptoService: CryptoService!
    var key: SymmetricKey!

    override func setUp() {
        super.setUp()
        cryptoService = CryptoService()
        key = SymmetricKey(size: .bits256)
    }

    func testEncryptAndDecryptData() throws {
        let plaintext = "TopSecretMediaData_2026".data(using: .utf8)!
        let ciphertext = try cryptoService.encrypt(data: plaintext, key: key)

        XCTAssertNotEqual(plaintext, ciphertext)
        XCTAssertGreaterThan(ciphertext.count, plaintext.count) // Nonce (12) + Tag (16)

        let decrypted = try cryptoService.decrypt(combinedCiphertext: ciphertext, key: key)
        XCTAssertEqual(plaintext, decrypted)
    }

    func testTamperedCiphertextFailsAuthentication() throws {
        let plaintext = "SensitiveImageData".data(using: .utf8)!
        var ciphertext = try cryptoService.encrypt(data: plaintext, key: key)

        // Modify byte in ciphertext to simulate tampering
        let tamperIndex = ciphertext.count / 2
        ciphertext[tamperIndex] ^= 0xFF

        XCTAssertThrowsError(try cryptoService.decrypt(combinedCiphertext: ciphertext, key: key)) { error in
            guard let cryptoErr = error as? CryptoError else {
                XCTFail("Expected CryptoError but got \(error)")
                return
            }
            if case .authenticationFailed = cryptoErr {
                // Expected
            } else {
                XCTFail("Expected authenticationFailed but got \(cryptoErr)")
            }
        }
    }

    func testDecryptionWithWrongKeyFails() throws {
        let plaintext = "ConfidentialVaultDocument".data(using: .utf8)!
        let ciphertext = try cryptoService.encrypt(data: plaintext, key: key)

        let wrongKey = SymmetricKey(size: .bits256)
        XCTAssertThrowsError(try cryptoService.decrypt(combinedCiphertext: ciphertext, key: wrongKey))
    }

    func testCalculateSHA256() {
        let testData = "PrivateVaultHashTest".data(using: .utf8)!
        let hash = cryptoService.calculateSHA256(data: testData)

        XCTAssertEqual(hash.count, 64) // 256 bits = 64 hex characters
        XCTAssertEqual(hash, cryptoService.calculateSHA256(data: testData)) // Deterministic
    }
}
