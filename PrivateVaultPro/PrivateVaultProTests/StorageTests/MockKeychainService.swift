//
//  MockKeychainService.swift
//  PrivateVaultProTests
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation
@testable import PrivateVaultPro

public final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func save(key: String, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = data
    }

    public func load(key: String) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        guard let data = storage[key] else {
            throw KeychainError.itemNotFound
        }
        return data
    }

    public func delete(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    public func exists(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage[key] != nil
    }

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}
