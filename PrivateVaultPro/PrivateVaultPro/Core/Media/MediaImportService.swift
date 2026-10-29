//
//  MediaImportService.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import UIKit
import Photos
import PhotosUI

public struct ImportProgress: Sendable {
    public let totalItems: Int
    public let processedItems: Int
    public let currentItemName: String
    public let percentage: Double

    public init(totalItems: Int, processedItems: Int, currentItemName: String) {
        self.totalItems = totalItems
        self.processedItems = processedItems
        self.currentItemName = currentItemName
        self.percentage = totalItems > 0 ? Double(processedItems) / Double(totalItems) : 0
    }
}

public struct ImportResult: Sendable {
    public let importedItems: [MediaItem]
    public let duplicatesSkipped: Int
    public let failedCount: Int
    public let deletedOriginalsCount: Int
    public let originalDeletionErrors: [String]
}

public enum MediaImportError: Error, LocalizedError {
    case cannotReadMedia
    case encryptionFailed
    case storageFailed
    case photoLibraryAccessDenied

    public var errorDescription: String? {
        switch self {
        case .cannotReadMedia: return "Cannot read selected media data."
        case .encryptionFailed: return "Encryption failed during import."
        case .storageFailed: return "Storage verification failed."
        case .photoLibraryAccessDenied: return "Photos library access is restricted or denied."
        }
    }
}

public protocol MediaImportServiceProtocol: Sendable {
    func importPhotosPickerItems(
        _ pickerItems: [PhotosPickerItem],
        into metadata: inout VaultMetadata,
        deleteOriginals: Bool,
        progressHandler: (@Sendable (ImportProgress) -> Void)?
    ) async throws -> ImportResult

    func importRawData(
        data: Data,
        filename: String,
        mediaType: MediaType,
        into metadata: inout VaultMetadata
    ) async throws -> MediaItem?
}

public final class MediaImportService: MediaImportServiceProtocol {
    private let vaultStorage: VaultStorageServiceProtocol
    private let cryptoService: CryptoServiceProtocol
    private let thumbnailService: ThumbnailServiceProtocol

    public init(
        vaultStorage: VaultStorageServiceProtocol,
        cryptoService: CryptoServiceProtocol,
        thumbnailService: ThumbnailServiceProtocol
    ) {
        self.vaultStorage = vaultStorage
        self.cryptoService = cryptoService
        self.thumbnailService = thumbnailService
    }

    public func importPhotosPickerItems(
        _ pickerItems: [PhotosPickerItem],
        into metadata: inout VaultMetadata,
        deleteOriginals: Bool,
        progressHandler: (@Sendable (ImportProgress) -> Void)?
    ) async throws -> ImportResult {
        var imported: [MediaItem] = []
        var duplicates = 0
        var failed = 0
        var assetIdentifiersToDelete: [String] = []

        let total = pickerItems.count

        for (index, item) in pickerItems.enumerated() {
            progressHandler?(ImportProgress(
                totalItems: total,
                processedItems: index,
                currentItemName: "Item \(index + 1) of \(total)"
            ))

            do {
                // Determine media type
                let isVideo = item.supportedContentTypes.contains { type in
                    type.conforms(to: .movie) || type.conforms(to: .video)
                }

                if isVideo {
                    if let movie = try await item.loadTransferable(type: VideoTransferable.self) {
                        let videoData = try Data(contentsOf: movie.url)
                        let hash = cryptoService.calculateSHA256(data: videoData)

                        // Check duplicate
                        if metadata.items.contains(where: { $0.sha256Hash == hash }) {
                            duplicates += 1
                            try? FileManager.default.removeItem(at: movie.url)
                            continue
                        }

                        // Generate thumbnail
                        let thumbData = await thumbnailService.generateThumbnail(fromVideoURL: movie.url, maxDimension: 320)

                        let mediaItem = MediaItem(
                            originalFilename: movie.url.lastPathComponent,
                            mediaType: .video,
                            fileSize: Int64(videoData.count),
                            durationSeconds: movie.duration,
                            sha256Hash: hash,
                            mimeType: "video/mp4"
                        )

                        try await vaultStorage.saveMedia(rawMediaData: videoData, item: mediaItem, rawThumbnailData: thumbData)
                        imported.append(mediaItem)
                        metadata.items.insert(mediaItem, at: 0)

                        if let assetID = item.itemIdentifier {
                            assetIdentifiersToDelete.append(assetID)
                        }

                        // Clean up temporary transferable
                        try? FileManager.default.removeItem(at: movie.url)
                    } else {
                        failed += 1
                    }
                } else {
                    // Photo handling
                    if let photoData = try await item.loadTransferable(type: Data.self) {
                        let hash = cryptoService.calculateSHA256(data: photoData)

                        if metadata.items.contains(where: { $0.sha256Hash == hash }) {
                            duplicates += 1
                            continue
                        }

                        let thumbData = thumbnailService.generateThumbnail(fromPhotoData: photoData, maxDimension: 320)
                        let dimensions = getImageDimensions(from: photoData)

                        let filename = item.itemIdentifier != nil ? "IMG_\(item.itemIdentifier!).jpg" : "IMG_\(UUID().uuidString).jpg"
                        let mediaItem = MediaItem(
                            originalFilename: filename,
                            mediaType: .photo,
                            fileSize: Int64(photoData.count),
                            pixelWidth: dimensions.width,
                            pixelHeight: dimensions.height,
                            sha256Hash: hash,
                            mimeType: "image/jpeg"
                        )

                        try await vaultStorage.saveMedia(rawMediaData: photoData, item: mediaItem, rawThumbnailData: thumbData)
                        imported.append(mediaItem)
                        metadata.items.insert(mediaItem, at: 0)

                        if let assetID = item.itemIdentifier {
                            assetIdentifiersToDelete.append(assetID)
                        }
                    } else {
                        failed += 1
                    }
                }
            } catch {
                failed += 1
            }
        }

        // Save updated metadata
        if !imported.isEmpty {
            let logSummary = "Imported \(imported.count) secure items"
            metadata.activityLogs.insert(
                ActivityLogEntry(actionType: .mediaImported, summary: logSummary),
                at: 0
            )
            try await vaultStorage.saveMetadata(metadata)
        }

        // Handle deletion of originals if requested
        var deletedCount = 0
        var deletionErrors: [String] = []

        if deleteOriginals && !assetIdentifiersToDelete.isEmpty {
            let deleteResult = await deleteOriginalAssets(identifiers: assetIdentifiersToDelete)
            deletedCount = deleteResult.deleted
            deletionErrors = deleteResult.errors
        }

        progressHandler?(ImportProgress(totalItems: total, processedItems: total, currentItemName: "Completed"))

        return ImportResult(
            importedItems: imported,
            duplicatesSkipped: duplicates,
            failedCount: failed,
            deletedOriginalsCount: deletedCount,
            originalDeletionErrors: deletionErrors
        )
    }

    public func importRawData(
        data: Data,
        filename: String,
        mediaType: MediaType,
        into metadata: inout VaultMetadata
    ) async throws -> MediaItem? {
        let hash = cryptoService.calculateSHA256(data: data)

        if metadata.items.contains(where: { $0.sha256Hash == hash }) {
            return nil
        }

        let thumbData: Data?
        var width = 0
        var height = 0

        if mediaType == .photo {
            thumbData = thumbnailService.generateThumbnail(fromPhotoData: data, maxDimension: 320)
            let dims = getImageDimensions(from: data)
            width = dims.width
            height = dims.height
        } else {
            thumbData = nil
        }

        let mediaItem = MediaItem(
            originalFilename: filename,
            mediaType: mediaType,
            fileSize: Int64(data.count),
            pixelWidth: width,
            pixelHeight: height,
            sha256Hash: hash,
            mimeType: mediaType == .photo ? "image/jpeg" : "video/mp4"
        )

        try await vaultStorage.saveMedia(rawMediaData: data, item: mediaItem, rawThumbnailData: thumbData)
        metadata.items.insert(mediaItem, at: 0)
        metadata.activityLogs.insert(
            ActivityLogEntry(actionType: .mediaImported, summary: "Imported 1 file"),
            at: 0
        )
        try await vaultStorage.saveMetadata(metadata)

        return mediaItem
    }

    // MARK: - Photo Deletion Helper

    private func deleteOriginalAssets(identifiers: [String]) async -> (deleted: Int, errors: [String]) {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return (0, ["Photos access was not authorized to delete originals."])
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard fetchResult.count > 0 else {
            return (0, [])
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(fetchResult)
            }, completionHandler: { success, error in
                if success {
                    continuation.resume(returning: (fetchResult.count, []))
                } else {
                    continuation.resume(returning: (0, [error?.localizedDescription ?? "Deletion failed"]))
                }
            })
        }
    }

    private func getImageDimensions(from data: Data) -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return (0, 0)
        }
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        return (width, height)
    }
}

// MARK: - Video Transferable Support

public struct VideoTransferable: Transferable {
    public let url: URL
    public let duration: Double?

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempCopy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
            try FileManager.default.copyItem(at: received.file, to: tempCopy)
            let asset = AVAsset(url: tempCopy)
            let durationSeconds = CMTimeGetSeconds(asset.duration)
            let validDuration = durationSeconds.isFinite && durationSeconds > 0 ? durationSeconds : nil
            return VideoTransferable(url: tempCopy, duration: validDuration)
        }
    }
}
