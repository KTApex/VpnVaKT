//
//  CorruptedBackupTests.swift
//  PrivateVaultProTests
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import XCTest
import CryptoKit
@testable import PrivateVaultPro

final class CorruptedBackupTests: XCTestCase {
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

    func testWrongPasswordThrowsIncorrectPassword() async throws {
        var metadata = VaultMetadata()
        let backupURL = try await backupService.createBackup(password: "CorrectPassword123", metadata: &metadata, progress: nil)

        XCTAssertThrowsError(
            try restoreService.decryptAndPreview(at: backupURL, password: "WrongPassword456", existingMetadata: VaultMetadata())
        ) { error in
            guard let restoreErr = error as? RestoreError else {
                XCTFail("Expected RestoreError")
                return
            }
            if case .incorrectPassword = restoreErr {
                // Passed
            } else {
                XCTFail("Expected incorrectPassword error")
            }
        }

        try? FileManager.default.removeItem(at: backupURL)
    }

    func testTamperedPayloadFailsIntegrityCheck() throws {
        // Manually assemble an archive with a modified payload that doesn't match manifest hash
        let manifest = BackupManifest(
            saltBase64: Data(repeating: 1, count: 16).base64EncodedString(),
            payloadSHA256: "0000000000000000000000000000000000000000000000000000000000000000",
            totalMediaCount: 0,
            photoCount: 0,
            videoCount: 0,
            albumCount: 0,
            totalPayloadBytes: 10
        )
        let manifestData = try JSONEncoder().encode(manifest)
        let fakePayloadData = "TamperedPayloadData".data(using: .utf8)!

        let entries = [
            ZipEntry(filename: "manifest.json", data: manifestData),
            ZipEntry(filename: "vault_payload.enc", data: fakePayloadData)
        ]
        let zipData = try BackupZipHandler.createArchive(entries: entries)

        let fileURL = tempDirectory.appendingPathComponent("tampered.zip")
        try zipData.write(to: fileURL)

        XCTAssertThrowsError(
            try restoreService.decryptAndPreview(at: fileURL, password: "AnyPassword", existingMetadata: VaultMetadata())
        ) { error in
            guard let restoreErr = error as? RestoreError else {
                XCTFail("Expected RestoreError")
                return
            }
            if case .payloadIntegrityMismatch = restoreErr {
                // Passed!
            } else {
                XCTFail("Expected payloadIntegrityMismatch")
            }
        }
    }

    func testCorruptedArchiveThrows() {
        let junkData = "NotAZipArchiveAtAll".data(using: .utf8)!
        let fileURL = tempDirectory.appendingPathComponent("garbage.zip")
        try? junkData.write(to: fileURL)

        XCTAssertThrowsError(try restoreService.inspectArchive(at: fileURL))
    }
}
