//
//  BackupManifest.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation

public struct BackupManifest: Codable, Sendable {
    public static let currentVersion = 1

    public let backupVersion: Int
    public let appVersion: String
    public let createdAt: Date
    public let kdfAlgorithm: String
    public let kdfIterations: UInt32
    public let saltBase64: String
    public let encryptionAlgorithm: String
    public let payloadSHA256: String
    public let totalMediaCount: Int
    public let photoCount: Int
    public let videoCount: Int
    public let albumCount: Int
    public let totalPayloadBytes: Int64

    public init(
        backupVersion: Int = BackupManifest.currentVersion,
        appVersion: String = "1.0.0",
        createdAt: Date = Date(),
        kdfAlgorithm: String = "PBKDF2-HMAC-SHA256",
        kdfIterations: UInt32 = PBKDF2KeyDerivation.defaultIterations,
        saltBase64: String,
        encryptionAlgorithm: String = "AES-256-GCM",
        payloadSHA256: String,
        totalMediaCount: Int,
        photoCount: Int,
        videoCount: Int,
        albumCount: Int,
        totalPayloadBytes: Int64
    ) {
        self.backupVersion = backupVersion
        self.appVersion = appVersion
        self.createdAt = createdAt
        self.kdfAlgorithm = kdfAlgorithm
        self.kdfIterations = kdfIterations
        self.saltBase64 = saltBase64
        self.encryptionAlgorithm = encryptionAlgorithm
        self.payloadSHA256 = payloadSHA256
        self.totalMediaCount = totalMediaCount
        self.photoCount = photoCount
        self.videoCount = videoCount
        self.albumCount = albumCount
        self.totalPayloadBytes = totalPayloadBytes
    }
}

/// The inner decrypted container payload structure
public struct DecryptedBackupPayload: Codable, Sendable {
    public let metadata: VaultMetadata
    /// Relative path within payload -> raw file data
    public let files: [String: Data]

    public init(metadata: VaultMetadata, files: [String: Data]) {
        self.metadata = metadata
        self.files = files
    }
}

public struct RestorePreview: Sendable {
    public let manifest: BackupManifest
    public let newPhotosCount: Int
    public let newVideosCount: Int
    public let existingPhotosCount: Int
    public let existingVideosCount: Int
    public let duplicatesCount: Int
}
