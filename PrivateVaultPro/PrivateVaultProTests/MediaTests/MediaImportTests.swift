//
//  MediaImportTests.swift
//  PrivateVaultProTests
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import XCTest
import CryptoKit
@testable import PrivateVaultPro

final class MediaImportTests: XCTestCase {
    var mediaImportService: MediaImportService!
    var vaultStorage: VaultStorageService!
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
        let thumbnailService = ThumbnailService()
        mediaImportService = MediaImportService(vaultStorage: vaultStorage, cryptoService: cryptoService, thumbnailService: thumbnailService)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testImportRawDataAndDeduplication() async throws {
        var metadata = VaultMetadata()
        let samplePhotoData = "RawPhotoBytesSample".data(using: .utf8)!

        // First import
        let item1 = try await mediaImportService.importRawData(
            data: samplePhotoData,
            filename: "photo1.jpg",
            mediaType: .photo,
            into: &metadata
        )

        XCTAssertNotNil(item1)
        XCTAssertEqual(metadata.items.count, 1)

        // Verify storage file exists and is encrypted
        let targetFile = vaultStorage.mediaDirectoryURL.appendingPathComponent(item1!.encryptedFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetFile.path))

        let onDiskData = try Data(contentsOf: targetFile)
        XCTAssertNotEqual(onDiskData, samplePhotoData) // Must be encrypted!

        // Attempt duplicate import of identical data
        let duplicateItem = try await mediaImportService.importRawData(
            data: samplePhotoData,
            filename: "photo1_copy.jpg",
            mediaType: .photo,
            into: &metadata
        )

        XCTAssertNil(duplicateItem) // Duplicate rejected
        XCTAssertEqual(metadata.items.count, 1) // Count remains 1
    }
}
