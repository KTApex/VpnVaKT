//
//  MediaThumbnailView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct MediaThumbnailView: View {
    public let item: MediaItem
    public let isSelected: Bool
    public let isSelectionMode: Bool
    public let vaultStorage: VaultStorageServiceProtocol
    public let thumbnailService: ThumbnailServiceProtocol

    @State private var thumbnailImage: UIImage? = nil
    @State private var isLoading: Bool = false

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.vaultSurface)
                        .overlay(
                            Image(systemName: item.mediaType.systemIcon)
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.3))
                        )
                }
            }
            .clipped()

            // Video duration badge
            if item.mediaType == .video {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                    if let duration = item.formattedDuration {
                        Text(duration)
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.65))
                .cornerRadius(4)
                .padding(6)
            }

            // Favorite Indicator
            if item.isFavorite {
                VStack {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.neonCoral)
                            .padding(6)
                            .shadow(radius: 2)
                        Spacer()
                    }
                    Spacer()
                }
            }

            // Selection Checkbox
            if isSelectionMode {
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.neonCyan : Color.black.opacity(0.4))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1.5)
                                )

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(6)
                    }
                    Spacer()
                }
            }
        }
        .task(id: item.id) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        if let cached = thumbnailService.getCachedImage(for: item.id) {
            self.thumbnailImage = cached
            return
        }

        do {
            if let thumbData = try await vaultStorage.loadThumbnailData(for: item),
               let image = UIImage(data: thumbData) {
                thumbnailService.setCachedImage(image, for: item.id)
                self.thumbnailImage = image
            } else if item.mediaType == .photo {
                // Fallback to loading full photo and generating thumbnail
                let fullData = try await vaultStorage.loadMediaData(for: item)
                if let thumbData = thumbnailService.generateThumbnail(fromPhotoData: fullData, maxDimension: 320),
                   let image = UIImage(data: thumbData) {
                    thumbnailService.setCachedImage(image, for: item.id)
                    self.thumbnailImage = image
                }
            }
        } catch {
            // Error loading thumbnail
        }
    }
}
