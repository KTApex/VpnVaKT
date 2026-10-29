//
//  MediaExportService.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import UIKit
import Photos

public enum MediaExportError: Error, LocalizedError {
    case photoLibraryPermissionDenied
    case exportFailed(String)
    case unsupportedMediaType

    public var errorDescription: String? {
        switch self {
        case .photoLibraryPermissionDenied:
            return "Photos access is required to export to the system photo library."
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .unsupportedMediaType:
            return "Unsupported media type for export."
        }
    }
}

public protocol MediaExportServiceProtocol: Sendable {
    func exportToPhotos(item: MediaItem) async throws
    func prepareForShare(item: MediaItem) async throws -> URL
}

public final class MediaExportService: MediaExportServiceProtocol {
    private let vaultStorage: VaultStorageServiceProtocol

    public init(vaultStorage: VaultStorageServiceProtocol) {
        self.vaultStorage = vaultStorage
    }

    public func exportToPhotos(item: MediaItem) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw MediaExportError.photoLibraryPermissionDenied
        }

        let mediaData = try await vaultStorage.loadMediaData(for: item)

        if item.mediaType == .photo {
            guard let image = UIImage(data: mediaData) else {
                throw MediaExportError.exportFailed("Could not decode image data.")
            }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }, completionHandler: { success, error in
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error ?? MediaExportError.exportFailed("Unknown error"))
                    }
                })
            }
        } else if item.mediaType == .video {
            let tempURL = try await vaultStorage.createTemporaryDecryptedURL(for: item)
            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
                }, completionHandler: { success, error in
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error ?? MediaExportError.exportFailed("Unknown error"))
                    }
                })
            }
        }
    }

    public func prepareForShare(item: MediaItem) async throws -> URL {
        return try await vaultStorage.createTemporaryDecryptedURL(for: item)
    }
}
