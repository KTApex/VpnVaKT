//
//  ZipSafetyValidator.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation

public enum ZipSafetyError: Error, LocalizedError {
    case pathTraversalDetected(String)
    case archiveTooLarge(Int64)
    case excessiveEntryCount(Int)
    case invalidHeaderSignature
    case malformedArchive(String)

    public var errorDescription: String? {
        switch self {
        case .pathTraversalDetected(let path):
            return "Security violation: Path traversal detected in entry '\(path)'."
        case .archiveTooLarge(let size):
            return "Archive exceeds maximum permitted size threshold (\(size) bytes)."
        case .excessiveEntryCount(let count):
            return "Archive contains an excessive number of entries (\(count))."
        case .invalidHeaderSignature:
            return "Invalid ZIP header signature. File is corrupted or not a valid ZIP."
        case .malformedArchive(let reason):
            return "Archive is malformed: \(reason)"
        }
    }
}

public struct ZipSafetyValidator {
    public static let maxAllowedFileSize: Int64 = 20 * 1024 * 1024 * 1024 // 20 GB
    public static let maxAllowedEntryCount: Int = 50_000

    /// Validates an entry filename to prevent path traversal / Zip Slip.
    public static func validateEntryPath(_ path: String) throws {
        // Reject absolute paths
        if path.starts(with: "/") || path.starts(with: "\\") || path.contains(":") {
            throw ZipSafetyError.pathTraversalDetected(path)
        }

        // Standardize components and check for ".."
        let components = path.components(separatedBy: CharacterSet(charactersIn: "/\\"))
        for component in components {
            if component == ".." || component.trimmingCharacters(in: .whitespaces).isEmpty && component != "" {
                throw ZipSafetyError.pathTraversalDetected(path)
            }
        }

        // Check if resolved path escapes the sandbox
        let normalized = (path as NSString).standardizingPath
        if normalized.starts(with: "..") || normalized.starts(with: "/") {
            throw ZipSafetyError.pathTraversalDetected(path)
        }
    }

    /// Validates entry count and total uncompressed size against DoS thresholds.
    public static func validateLimits(entryCount: Int, totalBytes: Int64) throws {
        if entryCount > maxAllowedEntryCount {
            throw ZipSafetyError.excessiveEntryCount(entryCount)
        }
        if totalBytes > maxAllowedFileSize {
            throw ZipSafetyError.archiveTooLarge(totalBytes)
        }
    }
}
