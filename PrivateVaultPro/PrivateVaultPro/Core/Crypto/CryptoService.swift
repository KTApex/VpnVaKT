//
//  CryptoService.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation
import CryptoKit

public enum CryptoError: Error, LocalizedError {
    case encryptionFailed(String)
    case decryptionFailed(String)
    case authenticationFailed
    case fileOperationFailed(String)
    case invalidCiphertextFormat

    public var errorDescription: String? {
        switch self {
        case .encryptionFailed(let reason):
            return "Encryption failed: \(reason)"
        case .decryptionFailed(let reason):
            return "Decryption failed: \(reason)"
        case .authenticationFailed:
            return "Data authentication failed. The key or password may be incorrect, or the file has been tampered with."
        case .fileOperationFailed(let reason):
            return "Cryptographic file operation failed: \(reason)"
        case .invalidCiphertextFormat:
            return "Ciphertext format is invalid or truncated."
        }
    }
}

public protocol CryptoServiceProtocol: Sendable {
    func encrypt(data: Data, key: SymmetricKey) throws -> Data
    func decrypt(combinedCiphertext: Data, key: SymmetricKey) throws -> Data
    func encryptFile(at sourceURL: URL, to destinationURL: URL, key: SymmetricKey) throws
    func decryptFile(at sourceURL: URL, to destinationURL: URL, key: SymmetricKey) throws
    func calculateSHA256(data: Data) -> String
    func calculateSHA256(forFileAt url: URL) throws -> String
}

public final class CryptoService: CryptoServiceProtocol {
    public init() {}

    /// Encrypts raw data using AES-GCM (256-bit key, 96-bit nonce, 128-bit tag).
    /// Returns the combined sealed box: [12-byte Nonce | Ciphertext | 16-byte Tag]
    public func encrypt(data: Data, key: SymmetricKey) throws -> Data {
        do {
            let nonce = AES.GCM.Nonce()
            let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
            guard let combined = sealedBox.combined else {
                throw CryptoError.encryptionFailed("Failed to produce combined ciphertext format.")
            }
            return combined
        } catch {
            throw CryptoError.encryptionFailed(error.localizedDescription)
        }
    }

    /// Decrypts and authenticates AES-GCM combined ciphertext data.
    public func decrypt(combinedCiphertext: Data, key: SymmetricKey) throws -> Data {
        // AES-GCM combined format requires at least 12 bytes nonce + 16 bytes tag = 28 bytes
        guard combinedCiphertext.count >= 28 else {
            throw CryptoError.invalidCiphertextFormat
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combinedCiphertext)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw CryptoError.authenticationFailed
        }
    }

    /// Stream/memory-safe file encryption to destination URL.
    public func encryptFile(at sourceURL: URL, to destinationURL: URL, key: SymmetricKey) throws {
        let rawData: Data
        do {
            rawData = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        } catch {
            throw CryptoError.fileOperationFailed("Could not read source file: \(error.localizedDescription)")
        }

        let encryptedData = try encrypt(data: rawData, key: key)

        do {
            // Write atomically with file protection
            try encryptedData.write(to: destinationURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw CryptoError.fileOperationFailed("Could not write encrypted file: \(error.localizedDescription)")
        }
    }

    /// Stream/memory-safe file decryption to destination URL.
    public func decryptFile(at sourceURL: URL, to destinationURL: URL, key: SymmetricKey) throws {
        let encryptedData: Data
        do {
            encryptedData = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        } catch {
            throw CryptoError.fileOperationFailed("Could not read encrypted file: \(error.localizedDescription)")
        }

        let decryptedData = try decrypt(combinedCiphertext: encryptedData, key: key)

        do {
            // Temporary decrypted target written atomically with complete protection
            try decryptedData.write(to: destinationURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw CryptoError.fileOperationFailed("Could not write decrypted file: \(error.localizedDescription)")
        }
    }

    /// Calculates hex-encoded SHA-256 digest of data.
    public func calculateSHA256(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Calculates hex-encoded SHA-256 digest of a file without loading entire file into memory at once.
    public func calculateSHA256(forFileAt url: URL) throws -> String {
        guard let inputStream = InputStream(url: url) else {
            throw CryptoError.fileOperationFailed("Cannot open input stream for hashing.")
        }
        inputStream.open()
        defer { inputStream.close() }

        var hasher = SHA256()
        let bufferSize = 64 * 1024 // 64 KB chunks
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while inputStream.hasBytesAvailable {
            let readBytes = inputStream.read(&buffer, maxLength: bufferSize)
            if readBytes < 0 {
                throw CryptoError.fileOperationFailed("Stream read error during hashing: \(inputStream.streamError?.localizedDescription ?? "unknown")")
            }
            if readBytes == 0 {
                break
            }
            hasher.update(data: Data(bytes: buffer, count: readBytes))
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
