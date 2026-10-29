//
//  VaultStorageService.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation
import CryptoKit

public enum VaultStorageError: Error, LocalizedError {
    case directoryCreationFailed(String)
    case itemNotFound(UUID)
    case readFailed(String)
    case writeFailed(String)
    case metadataCorrupted
    case storageUnavailable

    public var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let msg): return "Vault directory creation failed: \(msg)"
        case .itemNotFound(let id): return "Media item \(id) not found in vault."
        case .readFailed(let msg): return "Failed to read vault file: \(msg)"
        case .writeFailed(let msg): return "Failed to write encrypted file to vault: \(msg)"
        case .metadataCorrupted: return "Vault metadata file is corrupted or cannot be decrypted."
        case .storageUnavailable: return "Secure vault storage directory is unavailable."
        }
    }
}

public protocol VaultStorageServiceProtocol: Sendable {
    var vaultRootURL: URL { get }
    var mediaDirectoryURL: URL { get }
    var thumbnailDirectoryURL: URL { get }

    func initializeStorage() throws
    func saveMedia(rawMediaData: Data, item: MediaItem, rawThumbnailData: Data?) async throws
    func loadMediaData(for item: MediaItem) async throws -> Data
    func loadThumbnailData(for item: MediaItem) async throws -> Data?
    func createTemporaryDecryptedURL(for item: MediaItem) async throws -> URL
    func deleteMedia(item: MediaItem) async throws
    func saveMetadata(_ metadata: VaultMetadata) async throws
    func loadMetadata() async throws -> VaultMetadata
    func getStorageSize() -> Int64
    func clearAllData() async throws
}

public final class VaultStorageService: VaultStorageServiceProtocol {
    public let vaultRootURL: URL
    public let mediaDirectoryURL: URL
    public let thumbnailDirectoryURL: URL
    private let metadataFileURL: URL

    private let cryptoService: CryptoServiceProtocol
    private let keyManager: EncryptionKeyManagerProtocol
    private let fileManager = FileManager.default

    public init(
        customRootURL: URL? = nil,
        cryptoService: CryptoServiceProtocol,
        keyManager: EncryptionKeyManagerProtocol
    ) {
        self.cryptoService = cryptoService
        self.keyManager = keyManager

        let root: URL
        if let custom = customRootURL {
            root = custom
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            root = appSupport.appendingPathComponent("SecureVault", isDirectory: true)
        }

        self.vaultRootURL = root
        self.mediaDirectoryURL = root.appendingPathComponent("media", isDirectory: true)
        self.thumbnailDirectoryURL = root.appendingPathComponent("thumbnails", isDirectory: true)
        self.metadataFileURL = root.appendingPathComponent("metadata.enc")

        try? initializeStorage()
    }

    public func initializeStorage() throws {
        let directories = [vaultRootURL, mediaDirectoryURL, thumbnailDirectoryURL]
        for dir in directories {
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [
                    FileAttributeKey.protectionKey: FileProtectionType.complete
                ])
            }
        }
    }

    public func saveMedia(rawMediaData: Data, item: MediaItem, rawThumbnailData: Data?) async throws {
        let masterKey = try keyManager.getOrCreateMasterKey()

        // 1. Encrypt and save media payload
        let encryptedMedia = try cryptoService.encrypt(data: rawMediaData, key: masterKey)
        let destinationMediaURL = mediaDirectoryURL.appendingPathComponent(item.encryptedFileName)
        try encryptedMedia.write(to: destinationMediaURL, options: [.atomic, .completeFileProtection])

        // 2. Encrypt and save thumbnail if provided
        if let thumbData = rawThumbnailData {
            let encryptedThumb = try cryptoService.encrypt(data: thumbData, key: masterKey)
            let destinationThumbURL = thumbnailDirectoryURL.appendingPathComponent(item.thumbnailFileName)
            try encryptedThumb.write(to: destinationThumbURL, options: [.atomic, .completeFileProtection])
        }
    }

    public func loadMediaData(for item: MediaItem) async throws -> Data {
        let fileURL = mediaDirectoryURL.appendingPathComponent(item.encryptedFileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw VaultStorageError.itemNotFound(item.id)
        }

        let encryptedData = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let masterKey = try keyManager.getOrCreateMasterKey()
        return try cryptoService.decrypt(combinedCiphertext: encryptedData, key: masterKey)
    }

    public func loadThumbnailData(for item: MediaItem) async throws -> Data? {
        let fileURL = thumbnailDirectoryURL.appendingPathComponent(item.thumbnailFileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let encryptedData = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let masterKey = try keyManager.getOrCreateMasterKey()
        return try cryptoService.decrypt(combinedCiphertext: encryptedData, key: masterKey)
    }

    /// Creates a protected temporary plaintext file for video playback or export.
    /// File is created inside temporaryDirectory with completeFileProtection.
    public func createTemporaryDecryptedURL(for item: MediaItem) async throws -> URL {
        let decryptedData = try await loadMediaData(for: item)
        let ext = (item.originalFilename as NSString).pathExtension
        let safeExt = ext.isEmpty ? (item.mediaType == .video ? "mp4" : "jpg") : ext
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(safeExt)")

        try decryptedData.write(to: tempURL, options: [.atomic, .completeFileProtection])
        return tempURL
    }

    public func deleteMedia(item: MediaItem) async throws {
        let mediaFile = mediaDirectoryURL.appendingPathComponent(item.encryptedFileName)
        let thumbFile = thumbnailDirectoryURL.appendingPathComponent(item.thumbnailFileName)

        try? fileManager.removeItem(at: mediaFile)
        try? fileManager.removeItem(at: thumbFile)
    }

    public func saveMetadata(_ metadata: VaultMetadata) async throws {
        let masterKey = try keyManager.getOrCreateMasterKey()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let rawData = try encoder.encode(metadata)

        let encryptedData = try cryptoService.encrypt(data: rawData, key: masterKey)
        try encryptedData.write(to: metadataFileURL, options: [.atomic, .completeFileProtection])
    }

    public func loadMetadata() async throws -> VaultMetadata {
        guard fileManager.fileExists(atPath: metadataFileURL.path) else {
            // Return empty metadata for fresh vault
            return VaultMetadata()
        }

        let masterKey = try keyManager.getOrCreateMasterKey()
        let encryptedData = try Data(contentsOf: metadataFileURL, options: [.mappedIfSafe])
        let decryptedData = try cryptoService.decrypt(combinedCiphertext: encryptedData, key: masterKey)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(VaultMetadata.self, from: decryptedData)
    }

    public func getStorageSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: vaultRootURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = resourceValues.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    public func clearAllData() async throws {
        if fileManager.fileExists(atPath: vaultRootURL.path) {
            try fileManager.removeItem(at: vaultRootURL)
        }
        try initializeStorage()
    }
}
