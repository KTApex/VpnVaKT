//
//  AlbumsView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct AlbumsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var isShowingCreateSheet: Bool = false
    @State private var albumToDelete: Album? = nil
    @State private var isShowingDeleteConfirm: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.vaultGradient.ignoresSafeArea()

                if appState.metadata.albums.isEmpty {
                    emptyAlbumsView
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(appState.metadata.albums) { album in
                                NavigationLink(destination: AlbumDetailView(album: album)) {
                                    albumCard(for: album)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        albumToDelete = album
                                        isShowingDeleteConfirm = true
                                    } label: {
                                        Label("Delete Album", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Albums")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isShowingCreateSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.neonCyan)
                    }
                }
            }
            .sheet(isPresented: $isShowingCreateSheet) {
                CreateAlbumSheet()
            }
            .confirmationDialog(
                "Delete Album?",
                isPresented: $isShowingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Album Only", role: .destructive) {
                    if let album = albumToDelete {
                        var meta = appState.metadata
                        _ = appState.environment.albumService.deleteAlbum(id: album.id, in: &meta)
                        appState.metadata = meta
                        Task { await appState.saveMetadata() }
                        appState.showToast("Album deleted", type: .info)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Media items inside this album will remain safely stored in your All Media vault.")
            }
        }
    }

    // MARK: - Album Card

    private func albumCard(for album: Album) -> some View {
        let itemCount = appState.metadata.items.filter { $0.albumIDs.contains(album.id) }.count
        let coverItem = appState.metadata.items.first { $0.id == album.coverMediaItemID }
            ?? appState.metadata.items.first { $0.albumIDs.contains(album.id) }

        return VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.vaultSurface)
                    .aspectRatio(1, contentMode: .fill)

                if let cover = coverItem {
                    MediaThumbnailView(
                        item: cover,
                        isSelected: false,
                        isSelectionMode: false,
                        vaultStorage: appState.environment.vaultStorage,
                        thumbnailService: appState.environment.thumbnailService
                    )
                    .cornerRadius(14)
                } else {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(itemCount) \(itemCount == 1 ? "item" : "items")")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Empty State

    private var emptyAlbumsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            Text("No Albums Created")
                .font(.headline)
                .foregroundColor(.white)
            Text("Organize your photos and videos into custom protected collections.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: { isShowingCreateSheet = true }) {
                Text("Create First Album")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.neonCyan)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
            Spacer()
        }
    }
}
