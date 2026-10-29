//
//  RestoreService.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation
import CryptoKit

public enum RestoreStrategy: Sendable {
    case merge
    case replace
}

public enum RestoreError: Error, LocalizedError {
    case invalidBackupArchive
    case missingManifest
    case missingPayload
    case payloadIntegrityMismatch
    case incorrectPassword
    case invalidManifestFormat
    case restoreFailed(String)
    case emptyArchive

    public var errorDescription: String? {
        switch self {
        case .invalidBackupArchive: return "The selected file is not a valid PrivateVault backup archive."
        case .missingManifest: return "Archive is missing manifest.json."
        case .missingPayload: return "Archive is missing vault_payload.enc."
        case .payloadIntegrityMismatch: return "Payload integrity check failed. The archive may be corrupted or tampered with."
        case .incorrectPassword: return "Incorrect backup password. Decryption failed."
        case .invalidManifestFormat: return "Cannot parse backup manifest."
        case .restoreFailed(let msg): return "Restore failed and was rolled back: \(msg)"
        case .emptyArchive: return "The backup archive contains no items."
        }
    }
}

public protocol RestoreServiceProtocol: Sendable {
    func inspectArchive(at url: URL) throws -> BackupManifest
    func decryptAndPreview(at url: URL, password: String, existingMetadata: VaultMetadata) throws -> (manifest: BackupManifest, payload: DecryptedBackupPayload, preview: RestorePreview)
    func executeRestore(
        payload: DecryptedBackupPayload,
        strategy: RestoreStrategy,
        currentMetadata: inout VaultMetadata
    ) async throws
}

public final class RestoreService: RestoreServiceProtocol {
    private let vaultStorage: VaultStorageServiceProtocol
    private let cryptoService: CryptoServiceProtocol
    private let fileManager = FileManager.default

    public init(
        vaultStorage: VaultStorageServiceProtocol,
        cryptoService: CryptoServiceProtocol
    ) {
        self.vaultStorage = vaultStorage
        self.cryptoService = cryptoService
    }

    public func inspectArchive(at url: URL) throws -> BackupManifest {
        let zipData = try Data(contentsOf: url, options: [.mappedIfSafe])
        let entries = try BackupZipHandler.extractArchive(data: zipData)

        guard let manifestEntry = entries.first(where: { $0.filename == "manifest.json" }) else {
            throw RestoreError.missingManifest
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(BackupManifest.self, from: manifestEntry.data)
        } catch {
            throw RestoreError.invalidManifestFormat
        }
    }

    public func decryptAndPreview(
        at url: URL,
        password: String,
        existingMetadata: VaultMetadata
    ) throws -> (manifest: BackupManifest, payload: DecryptedBackupPayload, preview: RestorePreview) {
        let zipData = try Data(contentsOf: url, options: [.mappedIfSafe])
        let entries = try BackupZipHandler.extractArchive(data: zipData)

        guard let manifestEntry = entries.first(where: { $0.filename == "manifest.json" }) else {
            throw RestoreError.missingManifest
        }
        guard let payloadEntry = entries.first(where: { $0.filename == "vault_payload.enc" }) else {
            throw RestoreError.missingPayload
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(BackupManifest.self, from: manifestEntry.data)

        // 1. Verify payload SHA-256
        let calculatedHash = cryptoService.calculateSHA256(data: payloadEntry.data)
        guard calculatedHash.caseInsensitiveCompare(manifest.payloadSHA256) == .orderedSame else {
            throw RestoreError.payloadIntegrityMismatch
        }

        // 2. Decode salt
        guard let salt = Data(base64Encoded: manifest.saltBase64) else {
            throw RestoreError.invalidManifestFormat
        }

        // 3. Derive key
        let derivedKey: SymmetricKey
        do {
            derivedKey = try PBKDF2KeyDerivation.deriveKey(
                from: password,
                salt: salt,
                iterations: manifest.kdfIterations
            )
        } catch {
            throw RestoreError.incorrectPassword
        }

        // 4. Decrypt payload
        let decryptedData: Data
        do {
            decryptedData = try cryptoService.decrypt(combinedCiphertext: payloadEntry.data, key: derivedKey)
        } catch {
            throw RestoreError.incorrectPassword
        }

        // 5. Decode DecryptedBackupPayload
        let payload: DecryptedBackupPayload
        do {
            payload = try decoder.decode(DecryptedBackupPayload.self, from: decryptedData)
        } catch {
            throw RestoreError.restoreFailed("Could not parse decrypted payload.")
        }

        // 6. Calculate preview metrics
        let existingHashes = Set(existingMetadata.items.map { $0.sha256Hash })
        var newPhotos = 0
        var newVideos = 0
        var duplicates = 0

        for item in payload.metadata.items {
            if existingHashes.contains(item.sha256Hash) {
                duplicates += 1
            } else {
                if item.mediaType == .photo {
                    newPhotos += 1
                } else {
                    newVideos += 1
                }
            }
        }

        let preview = RestorePreview(
            manifest: manifest,
            newPhotosCount: newPhotos,
            newVideosCount: newVideos,
            existingPhotosCount: existingMetadata.photoCount,
            existingVideosCount: existingMetadata.videoCount,
            duplicatesCount: duplicates
        )

        return (manifest, payload, preview)
    }

    public func executeRestore(
        payload: DecryptedBackupPayload,
        strategy: RestoreStrategy,
        currentMetadata: inout VaultMetadata
    ) async throws {
        // Create transactional rollback snapshot
        let snapshotDir = fileManager.temporaryDirectory.appendingPathComponent("vault_rollback_\(UUID().uuidString)")
        let vaultRoot = vaultStorage.vaultRootURL

        do {
            // Take snapshot
            if fileManager.fileExists(atPath: vaultRoot.path) {
                try fileManager.copyItem(at: vaultRoot, to: snapshotDir)
            }
        } catch {
            throw RestoreError.restoreFailed("Unable to create safety rollback snapshot: \(error.localizedDescription)")
        }

        do {
            switch strategy {
            case .replace:
                // Clear media directory and thumbnail directory
                try? fileManager.removeItem(at: vaultStorage.mediaDirectoryURL)
                try? fileManager.removeItem(at: vaultStorage.thumbnailDirectoryURL)
                try vaultStorage.initializeStorage()

                // Write all files
                for (filename, fileData) in payload.files {
                    try ZipSafetyValidator.validateEntryPath(filename)
                    let targetURL: URL
                    if filename.contains(".thumb.") {
                        targetURL = vaultStorage.thumbnailDirectoryURL.appendingPathComponent(filename)
                    } else {
                        targetURL = vaultStorage.mediaDirectoryURL.appendingPathComponent(filename)
                    }
                    try fileData.write(to: targetURL, options: [.atomic, .completeFileProtection])
                }

                currentMetadata = payload.metadata
                currentMetadata.activityLogs.insert(
                    ActivityLogEntry(
                        actionType: .backupRestored,
                        summary: "Vault restored (Replaced \(payload.metadata.items.count) items)"
                    ),
                    at: 0
                )
                try await vaultStorage.saveMetadata(currentMetadata)

            case .merge:
                let existingHashes = Set(currentMetadata.items.map { $0.sha256Hash })
                var mergedItems = currentMetadata.items
                var restoredCount = 0

                for item in payload.metadata.items {
                    if !existingHashes.contains(item.sha256Hash) {
                        // Write media file if present in payload
                        if let mediaData = payload.files[item.encryptedFileName] {
                            let targetURL = vaultStorage.mediaDirectoryURL.appendingPathComponent(item.encryptedFileName)
                            try mediaData.write(to: targetURL, options: [.atomic, .completeFileProtection])
                        }
                        // Write thumb file if present
                        if let thumbData = payload.files[item.thumbnailFileName] {
                            let thumbURL = vaultStorage.thumbnailDirectoryURL.appendingPathComponent(item.thumbnailFileName)
                            try thumbData.write(to: thumbURL, options: [.atomic, .completeFileProtection])
                        }
                        mergedItems.append(item)
                        restoredCount += 1
                    }
                }

                // Merge albums by name
                var existingAlbums = currentMetadata.albums
                for incomingAlbum in payload.metadata.albums {
                    if !existingAlbums.contains(where: { $0.name.lowercased() == incomingAlbum.name.lowercased() }) {
                        existingAlbums.append(incomingAlbum)
                    }
                }

                currentMetadata.items = mergedItems
                currentMetadata.albums = existingAlbums
                currentMetadata.activityLogs.insert(
                    ActivityLogEntry(
                        actionType: .backupRestored,
                        summary: "Vault restored (Merged \(restoredCount) new items)"
                    ),
                    at: 0
                )
                try await vaultStorage.saveMetadata(currentMetadata)
            }

            // Clean up snapshot upon success
            try? fileManager.removeItem(at: snapshotDir)

        } catch {
            // Rollback on failure!
            if fileManager.fileExists(atPath: snapshotDir.path) {
                try? fileManager.removeItem(at: vaultRoot)
                try? fileManager.copyItem(at: snapshotDir, to: vaultRoot)
                try? fileManager.removeItem(at: snapshotDir)
            }
            throw RestoreError.restoreFailed("Restoration failed and was reverted to original state: \(error.localizedDescription)")
        }
    }
}
