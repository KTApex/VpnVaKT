//
//  VaultMetadata.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation

public struct VaultMetadata: Codable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var createdAt: Date
    public var lastBackupDate: Date?
    public var items: [MediaItem]
    public var albums: [Album]
    public var activityLogs: [ActivityLogEntry]

    public init(
        version: Int = VaultMetadata.currentVersion,
        createdAt: Date = Date(),
        lastBackupDate: Date? = nil,
        items: [MediaItem] = [],
        albums: [Album] = [],
        activityLogs: [ActivityLogEntry] = []
    ) {
        self.version = version
        self.createdAt = createdAt
        self.lastBackupDate = lastBackupDate
        self.items = items
        self.albums = albums
        self.activityLogs = activityLogs
    }

    public var totalMediaCount: Int {
        items.count
    }

    public var photoCount: Int {
        items.filter { $0.mediaType == .photo }.count
    }

    public var videoCount: Int {
        items.filter { $0.mediaType == .video }.count
    }

    public var totalStorageBytes: Int64 {
        items.reduce(0) { $0 + $1.fileSize }
    }
}
