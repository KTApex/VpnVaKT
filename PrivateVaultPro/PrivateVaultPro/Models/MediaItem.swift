//
//  MediaItem.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation

public enum MediaType: String, Codable, CaseIterable, Sendable {
    case photo
    case video

    public var systemIcon: String {
        switch self {
        case .photo: return "photo"
        case .video: return "video"
        }
    }

    public var displayName: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        }
    }
}

public struct MediaItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var originalFilename: String
    public var mediaType: MediaType
    public var creationDate: Date
    public var importedDate: Date
    public var fileSize: Int64
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var durationSeconds: Double?
    public var isFavorite: Bool
    public var albumIDs: Set<UUID>
    public var sha256Hash: String
    public var encryptedFileName: String
    public var thumbnailFileName: String
    public var mimeType: String

    public init(
        id: UUID = UUID(),
        originalFilename: String,
        mediaType: MediaType,
        creationDate: Date = Date(),
        importedDate: Date = Date(),
        fileSize: Int64,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        durationSeconds: Double? = nil,
        isFavorite: Bool = false,
        albumIDs: Set<UUID> = [],
        sha256Hash: String,
        encryptedFileName: String? = nil,
        thumbnailFileName: String? = nil,
        mimeType: String
    ) {
        self.id = id
        self.originalFilename = originalFilename
        self.mediaType = mediaType
        self.creationDate = creationDate
        self.importedDate = importedDate
        self.fileSize = fileSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.durationSeconds = durationSeconds
        self.isFavorite = isFavorite
        self.albumIDs = albumIDs
        self.sha256Hash = sha256Hash
        self.encryptedFileName = encryptedFileName ?? "\(id.uuidString).enc"
        self.thumbnailFileName = thumbnailFileName ?? "\(id.uuidString).thumb.enc"
        self.mimeType = mimeType
    }

    public var formattedDuration: String? {
        guard let durationSeconds = durationSeconds, durationSeconds > 0 else { return nil }
        let total = Int(durationSeconds)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public var formattedDimensions: String {
        guard pixelWidth > 0 && pixelHeight > 0 else { return "Unknown" }
        return "\(pixelWidth) × \(pixelHeight)"
    }
}
