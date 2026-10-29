//
//  VaultStorageTests.swift
//  PrivateVaultProTests
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import XCTest
import CryptoKit
@testable import PrivateVaultPro

final class VaultStorageTests: XCTestCase {
    var storageService: VaultStorageService!
    var tempDirectory: URL!
    var mockKeychain: MockKeychainService!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        mockKeychain = MockKeychainService()
        let keyManager = EncryptionKeyManager(keychainService: mockKeychain)
        let cryptoService = CryptoService()
        storageService = VaultStorageService(customRootURL: tempDirectory, cryptoService: cryptoService, keyManager: keyManager)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testSaveAndLoadMedia() async throws {
        let mediaData = "FakeRawImageData123".data(using: .utf8)!
        let thumbData = "FakeThumbnailData123".data(using: .utf8)!

        let item = MediaItem(
            originalFilename: "test.jpg",
            mediaType: .photo,
            fileSize: Int64(mediaData.count),
            sha256Hash: "hash123",
            mimeType: "image/jpeg"
        )

        try await storageService.saveMedia(rawMediaData: mediaData, item: item, rawThumbnailData: thumbData)

        let loadedMedia = try await storageService.loadMediaData(for: item)
        XCTAssertEqual(loadedMedia, mediaData)

        let loadedThumb = try await storageService.loadThumbnailData(for: item)
        XCTAssertEqual(loadedThumb, thumbData)
    }

    func testDeleteMediaRemovesFiles() async throws {
        let mediaData = "SampleMediaToDelete".data(using: .utf8)!
        let item = MediaItem(
            originalFilename: "delete.jpg",
            mediaType: .photo,
            fileSize: Int64(mediaData.count),
            sha256Hash: "hashDelete",
            mimeType: "image/jpeg"
        )

        try await storageService.saveMedia(rawMediaData: mediaData, item: item, rawThumbnailData: nil)
        try await storageService.deleteMedia(item: item)

        do {
            _ = try await storageService.loadMediaData(for: item)
            XCTFail("Should have thrown itemNotFound")
        } catch {
            // Expected
        }
    }

    func testSaveAndLoadMetadata() async throws {
        var metadata = VaultMetadata()
        metadata.albums.append(Album(name: "Secret Documents"))
        metadata.activityLogs.append(ActivityLogEntry(actionType: .vaultUnlocked, summary: "Vault unlocked"))

        try await storageService.saveMetadata(metadata)

        let loaded = try await storageService.loadMetadata()
        XCTAssertEqual(loaded.albums.count, 1)
        XCTAssertEqual(loaded.albums.first?.name, "Secret Documents")
        XCTAssertEqual(loaded.activityLogs.count, 1)
    }
}
