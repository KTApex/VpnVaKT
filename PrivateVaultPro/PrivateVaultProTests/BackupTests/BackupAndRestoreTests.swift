//
//  BackupAndRestoreTests.swift
//  PrivateVaultProTests
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import XCTest
import CryptoKit
@testable import PrivateVaultPro

final class BackupAndRestoreTests: XCTestCase {
    var vaultStorage: VaultStorageService!
    var backupService: BackupService!
    var restoreService: RestoreService!
    var cryptoService: CryptoService!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let mockKeychain = MockKeychainService()
        let keyManager = EncryptionKeyManager(keychainService: mockKeychain)
        cryptoService = CryptoService()
        vaultStorage = VaultStorageService(customRootURL: tempDirectory, cryptoService: cryptoService, keyManager: keyManager)
        backupService = BackupService(vaultStorage: vaultStorage, cryptoService: cryptoService)
        restoreService = RestoreService(vaultStorage: vaultStorage, cryptoService: cryptoService)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testCreateBackupAndInspectManifest() async throws {
        var metadata = VaultMetadata()
        let sampleData = "SampleEncryptedMediaData".data(using: .utf8)!
        let item = MediaItem(
            originalFilename: "vacation.jpg",
            mediaType: .photo,
            fileSize: Int64(sampleData.count),
            sha256Hash: cryptoService.calculateSHA256(data: sampleData),
            mimeType: "image/jpeg"
        )
        try await vaultStorage.saveMedia(rawMediaData: sampleData, item: item, rawThumbnailData: nil)
        metadata.items.append(item)
        metadata.albums.append(Album(name: "Summer 2026"))

        let backupPassword = "BackupMasterPassword123"
        let backupURL = try await backupService.createBackup(password: backupPassword, metadata: &metadata, progress: nil)

        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        XCTAssertTrue(backupURL.lastPathComponent.starts(with: "PrivateVault_Backup_"))
        XCTAssertTrue(backupURL.pathExtension == "zip")

        // Inspect manifest
        let manifest = try restoreService.inspectArchive(at: backupURL)
        XCTAssertEqual(manifest.backupVersion, 1)
        XCTAssertEqual(manifest.totalMediaCount, 1)
        XCTAssertEqual(manifest.photoCount, 1)
        XCTAssertEqual(manifest.videoCount, 0)
        XCTAssertEqual(manifest.albumCount, 1)
        XCTAssertFalse(manifest.saltBase64.isEmpty)
        XCTAssertFalse(manifest.payloadSHA256.isEmpty)

        // Decrypt and preview
        let (decryptedManifest, payload, preview) = try restoreService.decryptAndPreview(
            at: backupURL,
            password: backupPassword,
            existingMetadata: VaultMetadata()
        )

        XCTAssertEqual(decryptedManifest.payloadSHA256, manifest.payloadSHA256)
        XCTAssertEqual(payload.metadata.items.count, 1)
        XCTAssertEqual(preview.newPhotosCount, 1)
        XCTAssertEqual(preview.duplicatesCount, 0)

        try? FileManager.default.removeItem(at: backupURL)
    }

    func testMergeRestoration() async throws {
        // Vault A has item 1
        let data1 = "ItemOneData".data(using: .utf8)!
        let hash1 = cryptoService.calculateSHA256(data: data1)
        let item1 = MediaItem(originalFilename: "1.jpg", mediaType: .photo, fileSize: 10, sha256Hash: hash1, mimeType: "image/jpeg")
        var currentMetadata = VaultMetadata(items: [item1])

        // Backup has item 2
        let data2 = "ItemTwoData".data(using: .utf8)!
        let hash2 = cryptoService.calculateSHA256(data: data2)
        let item2 = MediaItem(originalFilename: "2.jpg", mediaType: .photo, fileSize: 20, sha256Hash: hash2, mimeType: "image/jpeg")
        let backupPayload = DecryptedBackupPayload(
            metadata: VaultMetadata(items: [item2], albums: [Album(name: "ImportedAlbum")]),
            files: [item2.encryptedFileName: data2]
        )

        try await restoreService.executeRestore(payload: backupPayload, strategy: .merge, currentMetadata: &currentMetadata)

        XCTAssertEqual(currentMetadata.items.count, 2)
        XCTAssertEqual(currentMetadata.albums.count, 1)
        XCTAssertEqual(currentMetadata.albums.first?.name, "ImportedAlbum")
    }

    func testReplaceRestoration() async throws {
        // Current vault has item 1
        let item1 = MediaItem(originalFilename: "old.jpg", mediaType: .photo, fileSize: 10, sha256Hash: "oldHash", mimeType: "image/jpeg")
        var currentMetadata = VaultMetadata(items: [item1])

        // Backup has new items
        let dataNew = "NewContent".data(using: .utf8)!
        let itemNew = MediaItem(originalFilename: "new.jpg", mediaType: .photo, fileSize: 50, sha256Hash: "newHash", mimeType: "image/jpeg")
        let backupPayload = DecryptedBackupPayload(
            metadata: VaultMetadata(items: [itemNew], albums: []),
            files: [itemNew.encryptedFileName: dataNew]
        )

        try await restoreService.executeRestore(payload: backupPayload, strategy: .replace, currentMetadata: &currentMetadata)

        XCTAssertEqual(currentMetadata.items.count, 1)
        XCTAssertEqual(currentMetadata.items.first?.originalFilename, "new.jpg")
    }
}
