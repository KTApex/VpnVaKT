//
//  PBKDF2KeyDerivation.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation
import CryptoKit
import CommonCrypto

public enum PBKDF2Error: Error, LocalizedError {
    case derivationFailed(Int32)
    case invalidSaltLength
    case emptyPassword

    public var errorDescription: String? {
        switch self {
        case .derivationFailed(let code):
            return "PBKDF2 key derivation failed with status code \(code)."
        case .invalidSaltLength:
            return "Salt length must be at least 16 bytes."
        case .emptyPassword:
            return "Password cannot be empty."
        }
    }
}

public struct PBKDF2KeyDerivation {
    public static let defaultIterations: UInt32 = 100_000
    public static let defaultKeyByteCount: Int = 32 // 256-bit AES key
    public static let defaultSaltByteCount: Int = 16

    /// Generates a cryptographically secure random salt of given length.
    public static func generateSalt(length: Int = defaultSaltByteCount) -> Data {
        var salt = Data(count: length)
        let result = salt.withUnsafeMutableBytes { ptr -> Int32 in
            guard let baseAddress = ptr.baseAddress else { return -1 }
            return SecRandomCopyBytes(kSecRandomDefault, length, baseAddress)
        }
        if result != errSecSuccess {
            // Fallback to random bytes
            var rng = SystemRandomNumberGenerator()
            var bytes = [UInt8]()
            for _ in 0..<length {
                bytes.append(UInt8.random(in: 0...255, using: &rng))
            }
            return Data(bytes)
        }
        return salt
    }

    /// Derives a 256-bit CryptoKit SymmetricKey using PBKDF2 with HMAC-SHA256.
    public static func deriveKey(
        from password: String,
        salt: Data,
        iterations: UInt32 = defaultIterations,
        derivedKeyLength: Int = defaultKeyByteCount
    ) throws -> SymmetricKey {
        guard !password.isEmpty else {
            throw PBKDF2Error.emptyPassword
        }
        guard salt.count >= 8 else {
            throw PBKDF2Error.invalidSaltLength
        }

        var derivedKeyData = Data(count: derivedKeyLength)
        let passwordData = Data(password.utf8)

        let status = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        iterations,
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        derivedKeyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw PBKDF2Error.derivationFailed(status)
        }

        return SymmetricKey(data: derivedKeyData)
    }
}
