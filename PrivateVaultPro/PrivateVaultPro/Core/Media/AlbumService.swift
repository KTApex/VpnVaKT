//
//  AlbumService.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation

public protocol AlbumServiceProtocol: Sendable {
    func createAlbum(name: String, in metadata: inout VaultMetadata) -> Album
    func renameAlbum(id: UUID, newName: String, in metadata: inout VaultMetadata) -> Bool
    func deleteAlbum(id: UUID, in metadata: inout VaultMetadata) -> Bool
    func addMedia(itemIDs: Set<UUID>, toAlbumID albumID: UUID, in metadata: inout VaultMetadata)
    func removeMedia(itemIDs: Set<UUID>, fromAlbumID albumID: UUID, in metadata: inout VaultMetadata)
    func toggleFavorite(itemID: UUID, in metadata: inout VaultMetadata) -> Bool
}

public final class AlbumService: AlbumServiceProtocol {
    public init() {}

    public func createAlbum(name: String, in metadata: inout VaultMetadata) -> Album {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "New Album" : trimmed
        let album = Album(name: finalName, sortOrder: metadata.albums.count)
        metadata.albums.append(album)
        metadata.activityLogs.insert(
            ActivityLogEntry(actionType: .albumCreated, summary: "Album created"),
            at: 0
        )
        return album
    }

    public func renameAlbum(id: UUID, newName: String, in metadata: inout VaultMetadata) -> Bool {
        guard let index = metadata.albums.firstIndex(where: { $0.id == id }) else {
            return false
        }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        metadata.albums[index].name = trimmed.isEmpty ? "Untitled Album" : trimmed
        metadata.activityLogs.insert(
            ActivityLogEntry(actionType: .albumModified, summary: "Album renamed"),
            at: 0
        )
        return true
    }

    public func deleteAlbum(id: UUID, in metadata: inout VaultMetadata) -> Bool {
        guard let index = metadata.albums.firstIndex(where: { $0.id == id }) else {
            return false
        }
        metadata.albums.remove(at: index)

        // Remove album reference from media items without deleting media
        for i in 0..<metadata.items.count {
            metadata.items[i].albumIDs.remove(id)
        }

        metadata.activityLogs.insert(
            ActivityLogEntry(actionType: .albumModified, summary: "Album deleted"),
            at: 0
        )
        return true
    }

    public func addMedia(itemIDs: Set<UUID>, toAlbumID albumID: UUID, in metadata: inout VaultMetadata) {
        for i in 0..<metadata.items.count {
            if itemIDs.contains(metadata.items[i].id) {
                metadata.items[i].albumIDs.insert(albumID)
            }
        }
        // Update album cover if none exists
        if let albumIndex = metadata.albums.firstIndex(where: { $0.id == albumID }),
           metadata.albums[albumIndex].coverMediaItemID == nil,
           let firstID = itemIDs.first {
            metadata.albums[albumIndex].coverMediaItemID = firstID
        }
    }

    public func removeMedia(itemIDs: Set<UUID>, fromAlbumID albumID: UUID, in metadata: inout VaultMetadata) {
        for i in 0..<metadata.items.count {
            if itemIDs.contains(metadata.items[i].id) {
                metadata.items[i].albumIDs.remove(albumID)
            }
        }
        // If cover was removed, pick another
        if let albumIndex = metadata.albums.firstIndex(where: { $0.id == albumID }),
           let coverID = metadata.albums[albumIndex].coverMediaItemID,
           itemIDs.contains(coverID) {
            let nextCover = metadata.items.first(where: { $0.albumIDs.contains(albumID) })
            metadata.albums[albumIndex].coverMediaItemID = nextCover?.id
        }
    }

    public func toggleFavorite(itemID: UUID, in metadata: inout VaultMetadata) -> Bool {
        guard let index = metadata.items.firstIndex(where: { $0.id == itemID }) else {
            return false
        }
        metadata.items[index].isFavorite.toggle()
        let newState = metadata.items[index].isFavorite
        metadata.activityLogs.insert(
            ActivityLogEntry(
                actionType: .favoriteToggled,
                summary: newState ? "Item added to favorites" : "Item removed from favorites"
            ),
            at: 0
        )
        return newState
    }
}
