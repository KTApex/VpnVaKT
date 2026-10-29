//
//  BackupService.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation
import CryptoKit

public enum BackupError: Error, LocalizedError {
    case emptyPassword
    case passwordTooShort
    case packagingFailed(String)
    case fileWriteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyPassword: return "Backup password cannot be empty."
        case .passwordTooShort: return "Backup password must be at least 6 characters."
        case .packagingFailed(let reason): return "Backup packaging failed: \(reason)"
        case .fileWriteFailed(let reason): return "Could not save backup file: \(reason)"
        }
    }
}

public protocol BackupServiceProtocol: Sendable {
    func createBackup(
        password: String,
        metadata: inout VaultMetadata,
        progress: (@Sendable (Double, String) -> Void)?
    ) async throws -> URL
}

public final class BackupService: BackupServiceProtocol {
    private let vaultStorage: VaultStorageServiceProtocol
    private let cryptoService: CryptoServiceProtocol

    public init(
        vaultStorage: VaultStorageServiceProtocol,
        cryptoService: CryptoServiceProtocol
    ) {
        self.vaultStorage = vaultStorage
        self.cryptoService = cryptoService
    }

    public func createBackup(
        password: String,
        metadata: inout VaultMetadata,
        progress: (@Sendable (Double, String) -> Void)?
    ) async throws -> URL {
        guard !password.isEmpty else {
            throw BackupError.emptyPassword
        }
        guard password.count >= 6 else {
            throw BackupError.passwordTooShort
        }

        progress?(0.05, "Deriving encryption keys...")

        // 1. Generate salt and derive backup key
        let salt = PBKDF2KeyDerivation.generateSalt(length: 16)
        let backupKey = try PBKDF2KeyDerivation.deriveKey(
            from: password,
            salt: salt,
            iterations: PBKDF2KeyDerivation.defaultIterations
        )

        progress?(0.20, "Collecting vault media...")

        // 2. Read all encrypted media and thumbnail files into memory/payload map
        var filesPayload: [String: Data] = [:]
        let fm = FileManager.default

        for (index, item) in metadata.items.enumerated() {
            let mediaURL = vaultStorage.mediaDirectoryURL.appendingPathComponent(item.encryptedFileName)
            if let mediaData = try? Data(contentsOf: mediaURL) {
                filesPayload[item.encryptedFileName] = mediaData
            }

            let thumbURL = vaultStorage.thumbnailDirectoryURL.appendingPathComponent(item.thumbnailFileName)
            if let thumbData = try? Data(contentsOf: thumbURL) {
                filesPayload[item.thumbnailFileName] = thumbData
            }

            let currentProgress = 0.20 + (Double(index + 1) / Double(max(1, metadata.items.count))) * 0.40
            progress?(currentProgress, "Securing media files (\(index + 1)/\(metadata.items.count))...")
        }

        // 3. Encode inner payload
        progress?(0.65, "Encoding vault payload...")
        let innerPayload = DecryptedBackupPayload(metadata: metadata, files: filesPayload)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payloadData = try encoder.encode(innerPayload)

        // 4. Encrypt payload with AES-GCM using backup key
        progress?(0.75, "Encrypting backup archive...")
        let encryptedPayload = try cryptoService.encrypt(data: payloadData, key: backupKey)
        let payloadHash = cryptoService.calculateSHA256(data: encryptedPayload)

        // 5. Build manifest
        let manifest = BackupManifest(
            backupVersion: 1,
            appVersion: "1.0.0",
            createdAt: Date(),
            kdfAlgorithm: "PBKDF2-HMAC-SHA256",
            kdfIterations: PBKDF2KeyDerivation.defaultIterations,
            saltBase64: salt.base64EncodedString(),
            encryptionAlgorithm: "AES-256-GCM",
            payloadSHA256: payloadHash,
            totalMediaCount: metadata.items.count,
            photoCount: metadata.photoCount,
            videoCount: metadata.videoCount,
            albumCount: metadata.albums.count,
            totalPayloadBytes: Int64(encryptedPayload.count)
        )

        let manifestData = try encoder.encode(manifest)

        // 6. Create ZIP archive
        progress?(0.85, "Packaging into portable ZIP...")
        let entries: [ZipEntry] = [
            ZipEntry(filename: "manifest.json", data: manifestData),
            ZipEntry(filename: "vault_payload.enc", data: encryptedPayload)
        ]

        let zipData = try BackupZipHandler.createArchive(entries: entries)

        // 7. Save file to temporary directory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        let filename = "PrivateVault_Backup_\(dateString).zip"
        let outputURL = fm.temporaryDirectory.appendingPathComponent(filename)

        try? fm.removeItem(at: outputURL)
        do {
            try zipData.write(to: outputURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw BackupError.fileWriteFailed(error.localizedDescription)
        }

        // 8. Update metadata
        metadata.lastBackupDate = Date()
        metadata.activityLogs.insert(
            ActivityLogEntry(
                actionType: .backupCreated,
                summary: "Backup created (\(ByteCountFormatter.string(fromByteCount: Int64(zipData.count), countStyle: .file)))"
            ),
            at: 0
        )
        try await vaultStorage.saveMetadata(metadata)

        progress?(1.0, "Backup completed successfully!")
        return outputURL
    }
}
