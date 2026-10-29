//
//  ActivityLogEntry.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation

public enum ActionType: String, Codable, Sendable {
    case vaultUnlocked
    case vaultLocked
    case mediaImported
    case mediaDeleted
    case mediaExported
    case backupCreated
    case backupRestored
    case albumCreated
    case albumModified
    case favoriteToggled
    case pinChanged

    public var systemIcon: String {
        switch self {
        case .vaultUnlocked: return "lock.open.fill"
        case .vaultLocked: return "lock.fill"
        case .mediaImported: return "square.and.arrow.down.fill"
        case .mediaDeleted: return "trash.fill"
        case .mediaExported: return "square.and.arrow.up.fill"
        case .backupCreated: return "arrow.down.doc.fill"
        case .backupRestored: return "arrow.up.doc.fill"
        case .albumCreated: return "rectangle.stack.badge.plus"
        case .albumModified: return "rectangle.stack"
        case .favoriteToggled: return "heart.fill"
        case .pinChanged: return "key.fill"
        }
    }
}

public struct ActivityLogEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let actionType: ActionType
    /// A sanitized description that never contains sensitive media names or plaintext hashes.
    public let summary: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        actionType: ActionType,
        summary: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actionType = actionType
        self.summary = summary
    }
}
