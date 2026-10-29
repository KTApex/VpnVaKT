//
//  MediaDetailView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct MediaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    public let item: MediaItem
    public let onDelete: (MediaItem) -> Void

    @State private var fullImage: UIImage? = nil
    @State private var isLoading: Bool = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var isShowingInfoSheet: Bool = false
    @State private var isShowingDeleteConfirm: Bool = false
    @State private var isShowingShareSheet: Bool = false
    @State private var shareURL: URL? = nil
    @State private var isShowingAddToAlbumSheet: Bool = false

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if item.mediaType == .photo {
                photoContentView
            } else {
                VideoPlayerView(item: item, vaultStorage: appState.environment.vaultStorage)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(item.creationDate.relativeOrFormattedString)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text(item.originalFilename)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: toggleFavorite) {
                    Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(item.isFavorite ? .neonCoral : .white)
                }

                Button(action: { isShowingInfoSheet = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.white)
                }

                Menu {
                    Button(action: prepareShare) {
                        Label("Share / Export", systemImage: "square.and.arrow.up")
                    }

                    Button(action: { isShowingAddToAlbumSheet = true }) {
                        Label("Add to Album", systemImage: "rectangle.stack.badge.plus")
                    }

                    Divider()

                    Button(role: .destructive, action: { isShowingDeleteConfirm = true }) {
                        Label("Delete from Vault", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.white)
                }
            }
        }
        .task {
            if item.mediaType == .photo {
                await loadFullPhoto()
            }
        }
        .sheet(isPresented: $isShowingInfoSheet) {
            infoSheetView
                .presentationDetents([.medium])
                .presentationBackground(Color.vaultDeepNavy)
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $isShowingAddToAlbumSheet) {
            addToAlbumSheetView
                .presentationDetents([.medium])
                .presentationBackground(Color.vaultDeepNavy)
        }
        .confirmationDialog(
            "Delete Item?",
            isPresented: $isShowingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete permanently", role: .destructive) {
                deleteCurrentItem()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This item will be permanently removed from your encrypted vault.")
        }
    }

    // MARK: - Photo Viewer with Pinch Zoom

    private var photoContentView: some View {
        Group {
            if let image = fullImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                let newScale = scale * delta
                                scale = min(max(newScale, 1.0), 5.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1.0 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            scale = scale > 1.0 ? 1.0 : 2.5
                        }
                    }
            } else if isLoading {
                ProgressView()
                    .tint(.neonCyan)
            } else {
                Text("Failed to decrypt image")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Info Sheet

    private var infoSheetView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Media Security Info")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { isShowingInfoSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            VStack(spacing: 12) {
                infoRow(title: "Filename", value: item.originalFilename)
                infoRow(title: "Media Type", value: item.mediaType.displayName)
                infoRow(title: "File Size", value: ByteCountFormatter.formatBytes(item.fileSize))
                infoRow(title: "Dimensions", value: item.formattedDimensions)
                infoRow(title: "Imported", value: item.importedDate.fullDateTimeString)
                infoRow(title: "Encryption", value: "AES-256-GCM Authenticated")
                infoRow(title: "SHA-256 Hash", value: String(item.sha256Hash.prefix(16)) + "...")
            }

            Spacer()
        }
        .padding()
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }

    // MARK: - Add To Album Sheet

    private var addToAlbumSheetView: some View {
        NavigationStack {
            List {
                if appState.metadata.albums.isEmpty {
                    Text("No albums available. Create one in the Albums tab.")
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    ForEach(appState.metadata.albums) { album in
                        Button(action: {
                            var meta = appState.metadata
                            appState.environment.albumService.addMedia(
                                itemIDs: [item.id],
                                toAlbumID: album.id,
                                in: &meta
                            )
                            appState.metadata = meta
                            Task { await appState.saveMetadata() }
                            isShowingAddToAlbumSheet = false
                            appState.showToast("Added to \(album.name)", type: .success)
                        }) {
                            HStack {
                                Image(systemName: "rectangle.stack.fill")
                                    .foregroundColor(.neonCyan)
                                Text(album.name)
                                    .foregroundColor(.white)
                                Spacer()
                                if item.albumIDs.contains(album.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.neonEmerald)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.vaultDeepNavy)
            .navigationTitle("Add to Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isShowingAddToAlbumSheet = false }
                        .foregroundColor(.neonCyan)
                }
            }
        }
    }

    // MARK: - Actions

    private func loadFullPhoto() async {
        do {
            let data = try await appState.environment.vaultStorage.loadMediaData(for: item)
            self.fullImage = UIImage(data: data)
            self.isLoading = false
        } catch {
            self.isLoading = false
        }
    }

    private func toggleFavorite() {
        HapticFeedback.impact(.light)
        var meta = appState.metadata
        _ = appState.environment.albumService.toggleFavorite(itemID: item.id, in: &meta)
        appState.metadata = meta
        Task { await appState.saveMetadata() }
    }

    private func prepareShare() {
        Task {
            do {
                let url = try await appState.environment.mediaExportService.prepareForShare(item: item)
                self.shareURL = url
                self.isShowingShareSheet = true
            } catch {
                appState.showToast("Export failed: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func deleteCurrentItem() {
        onDelete(item)
        dismiss()
    }
}
