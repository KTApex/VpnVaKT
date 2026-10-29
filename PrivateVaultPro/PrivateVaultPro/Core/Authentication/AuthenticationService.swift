//
//  AuthenticationService.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation
import CryptoKit

public enum AuthenticationError: Error, LocalizedError {
    case pinMismatch
    case invalidPinFormat
    case noPinConfigured
    case biometricFailed(String)
    case lockedOut(secondsRemaining: Int)

    public var errorDescription: String? {
        switch self {
        case .pinMismatch:
            return "Incorrect PIN. Please try again."
        case .invalidPinFormat:
            return "PIN must be between 4 and 6 digits."
        case .noPinConfigured:
            return "No master PIN has been configured."
        case .biometricFailed(let msg):
            return "Biometric verification failed: \(msg)"
        case .lockedOut(let sec):
            return "Too many failed attempts. Try again in \(sec) seconds."
        }
    }
}

public protocol AuthenticationServiceProtocol: AnyObject, Sendable {
    var isUnlocked: Bool { get }
    var hasConfiguredPIN: Bool { get }
    var biometryType: SupportedBiometryType { get }

    func authenticateWithBiometrics() async throws -> Bool
    func authenticateWithPIN(_ pin: String) -> Bool
    func setupPIN(_ pin: String) throws
    func changePIN(oldPIN: String, newPIN: String) throws -> Bool
    func lock()
    func recordBackgroundTransition()
    func shouldAutoLock(timeout: AutoLockTimeout) -> Bool
    func resetFailedAttempts()
}

public final class AuthenticationService: AuthenticationServiceProtocol, @unchecked Sendable {
    private let keychainService: KeychainServiceProtocol
    private let biometricManager: BiometricManagerProtocol

    private let pinHashKey = "vault_pin_hash_v1"
    private let pinSaltKey = "vault_pin_salt_v1"

    private let lockQueue = DispatchQueue(label: "com.privatevaultpro.authservice.lock")
    private var _isUnlocked: Bool = false
    private var backgroundTimestamp: Date?
    private var failedAttempts: Int = 0
    private var lockoutExpirationDate: Date?

    public var isUnlocked: Bool {
        lockQueue.sync { _isUnlocked }
    }

    public var hasConfiguredPIN: Bool {
        keychainService.exists(key: pinHashKey) && keychainService.exists(key: pinSaltKey)
    }

    public var biometryType: SupportedBiometryType {
        biometricManager.biometryType
    }

    public init(
        keychainService: KeychainServiceProtocol,
        biometricManager: BiometricManagerProtocol = BiometricManager()
    ) {
        self.keychainService = keychainService
        self.biometricManager = biometricManager
    }

    public func authenticateWithBiometrics() async throws -> Bool {
        guard !isLockedOut() else {
            let remaining = getRemainingLockoutSeconds()
            throw AuthenticationError.lockedOut(secondsRemaining: remaining)
        }

        let success = try await biometricManager.authenticate(reason: "Unlock your private media vault")
        if success {
            lockQueue.sync {
                self._isUnlocked = true
                self.failedAttempts = 0
                self.lockoutExpirationDate = nil
            }
            return true
        } else {
            return false
        }
    }

    public func authenticateWithPIN(_ pin: String) -> Bool {
        if isLockedOut() {
            return false
        }

        guard let storedHash = try? keychainService.load(key: pinHashKey),
              let storedSalt = try? keychainService.load(key: pinSaltKey) else {
            return false
        }

        let computedHash = computeHash(pin: pin, salt: storedSalt)
        let matches = (computedHash == storedHash)

        lockQueue.sync {
            if matches {
                self._isUnlocked = true
                self.failedAttempts = 0
                self.lockoutExpirationDate = nil
            } else {
                self.failedAttempts += 1
                if self.failedAttempts >= 5 {
                    // Lock out for 30 seconds after 5 failed attempts
                    self.lockoutExpirationDate = Date().addingTimeInterval(30)
                }
            }
        }

        return matches
    }

    public func setupPIN(_ pin: String) throws {
        guard pin.count >= 4 && pin.count <= 6, CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: pin)) else {
            throw AuthenticationError.invalidPinFormat
        }

        let salt = PBKDF2KeyDerivation.generateSalt(length: 16)
        let hash = computeHash(pin: pin, salt: salt)

        try keychainService.save(key: pinSaltKey, data: salt)
        try keychainService.save(key: pinHashKey, data: hash)

        lockQueue.sync {
            self._isUnlocked = true
            self.failedAttempts = 0
        }
    }

    public func changePIN(oldPIN: String, newPIN: String) throws -> Bool {
        guard authenticateWithPIN(oldPIN) else {
            throw AuthenticationError.pinMismatch
        }
        try setupPIN(newPIN)
        return true
    }

    public func lock() {
        lockQueue.sync {
            self._isUnlocked = false
            self.backgroundTimestamp = nil
        }
    }

    public func recordBackgroundTransition() {
        lockQueue.sync {
            self.backgroundTimestamp = Date()
        }
    }

    public func shouldAutoLock(timeout: AutoLockTimeout) -> Bool {
        lockQueue.sync {
            guard _isUnlocked else { return false }
            switch timeout {
            case .immediate:
                return true
            case .never:
                return false
            case .thirtySeconds, .oneMinute, .fiveMinutes:
                guard let timestamp = self.backgroundTimestamp else {
                    return false
                }
                let elapsed = Date().timeIntervalSince(timestamp)
                return elapsed >= Double(timeout.rawValue)
            }
        }
    }

    public func resetFailedAttempts() {
        lockQueue.sync {
            self.failedAttempts = 0
            self.lockoutExpirationDate = nil
        }
    }

    // MARK: - Private Helpers

    private func isLockedOut() -> Bool {
        lockQueue.sync {
            guard let lockout = self.lockoutExpirationDate else { return false }
            if Date() < lockout {
                return true
            } else {
                self.lockoutExpirationDate = nil
                self.failedAttempts = 0
                return false
            }
        }
    }

    private func getRemainingLockoutSeconds() -> Int {
        lockQueue.sync {
            guard let lockout = self.lockoutExpirationDate else { return 0 }
            let remaining = Int(lockout.timeIntervalSinceNow)
            return max(0, remaining)
        }
    }

    private func computeHash(pin: String, salt: Data) -> Data {
        var input = salt
        input.append(Data(pin.utf8))
        let digest = SHA256.hash(data: input)
        return Data(digest)
    }
}
