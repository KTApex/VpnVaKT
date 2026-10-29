//
//  EncryptionKeyManager.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation
import CryptoKit

public protocol EncryptionKeyManagerProtocol: Sendable {
    func getOrCreateMasterKey() throws -> SymmetricKey
    func resetMasterKey() throws -> SymmetricKey
    func hasMasterKey() -> Bool
}

public final class EncryptionKeyManager: EncryptionKeyManagerProtocol {
    private let keychainService: KeychainServiceProtocol
    private let keyIdentifier = "master_vault_aes256_key"

    public init(keychainService: KeychainServiceProtocol) {
        self.keychainService = keychainService
    }

    public func getOrCreateMasterKey() throws -> SymmetricKey {
        if keychainService.exists(key: keyIdentifier) {
            let keyData = try keychainService.load(key: keyIdentifier)
            return SymmetricKey(data: keyData)
        } else {
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            try keychainService.save(key: keyIdentifier, data: keyData)
            return newKey
        }
    }

    public func resetMasterKey() throws -> SymmetricKey {
        try? keychainService.delete(key: keyIdentifier)
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try keychainService.save(key: keyIdentifier, data: keyData)
        return newKey
    }

    public func hasMasterKey() -> Bool {
        keychainService.exists(key: keyIdentifier)
    }
}
