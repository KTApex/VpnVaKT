//
//  AppEnvironment.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation

public final class AppEnvironment: @unchecked Sendable {
    public let cryptoService: CryptoServiceProtocol
    public let keychainService: KeychainServiceProtocol
    public let keyManager: EncryptionKeyManagerProtocol
    public let vaultStorage: VaultStorageServiceProtocol
    public let authService: AuthenticationServiceProtocol
    public let biometricManager: BiometricManagerProtocol
    public let mediaImportService: MediaImportServiceProtocol
    public let mediaExportService: MediaExportServiceProtocol
    public let albumService: AlbumServiceProtocol
    public let thumbnailService: ThumbnailServiceProtocol
    public let backupService: BackupServiceProtocol
    public let restoreService: RestoreServiceProtocol

    public init(
        cryptoService: CryptoServiceProtocol,
        keychainService: KeychainServiceProtocol,
        keyManager: EncryptionKeyManagerProtocol,
        vaultStorage: VaultStorageServiceProtocol,
        authService: AuthenticationServiceProtocol,
        biometricManager: BiometricManagerProtocol,
        mediaImportService: MediaImportServiceProtocol,
        mediaExportService: MediaExportServiceProtocol,
        albumService: AlbumServiceProtocol,
        thumbnailService: ThumbnailServiceProtocol,
        backupService: BackupServiceProtocol,
        restoreService: RestoreServiceProtocol
    ) {
        self.cryptoService = cryptoService
        self.keychainService = keychainService
        self.keyManager = keyManager
        self.vaultStorage = vaultStorage
        self.authService = authService
        self.biometricManager = biometricManager
        self.mediaImportService = mediaImportService
        self.mediaExportService = mediaExportService
        self.albumService = albumService
        self.thumbnailService = thumbnailService
        self.backupService = backupService
        self.restoreService = restoreService
    }

    public static let shared: AppEnvironment = {
        let crypto = CryptoService()
        let keychain = KeychainService()
        let keyMgr = EncryptionKeyManager(keychainService: keychain)
        let storage = VaultStorageService(cryptoService: crypto, keyManager: keyMgr)
        let bioMgr = BiometricManager()
        let auth = AuthenticationService(keychainService: keychain, biometricManager: bioMgr)
        let thumb = ThumbnailService()
        let mediaImport = MediaImportService(vaultStorage: storage, cryptoService: crypto, thumbnailService: thumb)
        let mediaExport = MediaExportService(vaultStorage: storage)
        let album = AlbumService()
        let backup = BackupService(vaultStorage: storage, cryptoService: crypto)
        let restore = RestoreService(vaultStorage: storage, cryptoService: crypto)

        return AppEnvironment(
            cryptoService: crypto,
            keychainService: keychain,
            keyManager: keyMgr,
            vaultStorage: storage,
            authService: auth,
            biometricManager: bioMgr,
            mediaImportService: mediaImport,
            mediaExportService: mediaExport,
            albumService: album,
            thumbnailService: thumb,
            backupService: backup,
            restoreService: restore
        )
    }()
}
