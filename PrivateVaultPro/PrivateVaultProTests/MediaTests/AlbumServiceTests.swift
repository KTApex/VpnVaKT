//
//  AlbumServiceTests.swift
//  PrivateVaultProTests
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import XCTest
@testable import PrivateVaultPro

final class AlbumServiceTests: XCTestCase {
    var albumService: AlbumService!

    override func setUp() {
        super.setUp()
        albumService = AlbumService()
    }

    func testCreateAndRenameAlbum() {
        var metadata = VaultMetadata()
        let album = albumService.createAlbum(name: "Finance", in: &metadata)

        XCTAssertEqual(metadata.albums.count, 1)
        XCTAssertEqual(metadata.albums.first?.name, "Finance")

        let renamed = albumService.renameAlbum(id: album.id, newName: "Banking & Tax", in: &metadata)
        XCTAssertTrue(renamed)
        XCTAssertEqual(metadata.albums.first?.name, "Banking & Tax")
    }

    func testDeleteAlbumKeepsMediaIntact() {
        var metadata = VaultMetadata()
        let album = albumService.createAlbum(name: "Vacation", in: &metadata)

        let itemID = UUID()
        let item = MediaItem(
            id: itemID,
            originalFilename: "beach.jpg",
            mediaType: .photo,
            fileSize: 100,
            albumIDs: [album.id],
            sha256Hash: "hashBeach",
            mimeType: "image/jpeg"
        )
        metadata.items.append(item)

        XCTAssertTrue(metadata.items.first?.albumIDs.contains(album.id) == true)

        let deleted = albumService.deleteAlbum(id: album.id, in: &metadata)
        XCTAssertTrue(deleted)
        XCTAssertEqual(metadata.albums.count, 0)

        // Media item is still present, only album reference removed!
        XCTAssertEqual(metadata.items.count, 1)
        XCTAssertFalse(metadata.items.first?.albumIDs.contains(album.id) == true)
    }

    func testToggleFavorite() {
        var metadata = VaultMetadata()
        let itemID = UUID()
        let item = MediaItem(
            id: itemID,
            originalFilename: "favorite.jpg",
            mediaType: .photo,
            fileSize: 100,
            isFavorite: false,
            sha256Hash: "hashFav",
            mimeType: "image/jpeg"
        )
        metadata.items.append(item)

        let isFav = albumService.toggleFavorite(itemID: itemID, in: &metadata)
        XCTAssertTrue(isFav)
        XCTAssertTrue(metadata.items.first?.isFavorite == true)

        let isFavAgain = albumService.toggleFavorite(itemID: itemID, in: &metadata)
        XCTAssertFalse(isFavAgain)
        XCTAssertFalse(metadata.items.first?.isFavorite == true)
    }
}
