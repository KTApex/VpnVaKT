//
//  AlbumDetailView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct AlbumDetailView: View {
    @EnvironmentObject private var appState: AppState

    public let album: Album

    @State private var selectedItemIDs: Set<UUID> = []
    @State private var isSelectionMode: Bool = false
    @State private var selectedItemForDetail: MediaItem? = nil
    @State private var isShowingRenameAlert: Bool = false
    @State private var renameText: String = ""

    private var albumItems: [MediaItem] {
        appState.metadata.items.filter { $0.albumIDs.contains(album.id) }
    }

    public var body: some View {
        ZStack {
            Color.vaultGradient.ignoresSafeArea()

            if albumItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.3))
                    Text("This album is empty")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Select photos or videos in the Gallery tab to add them here.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                MediaGridView(
                    items: albumItems,
                    columnCount: appState.settings.gridColumnCount,
                    isSelectionMode: isSelectionMode,
                    selectedIDs: $selectedItemIDs,
                    onItemTap: { item in
                        selectedItemForDetail = item
                    },
                    vaultStorage: appState.environment.vaultStorage,
                    thumbnailService: appState.environment.thumbnailService
                )
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: {
                        renameText = album.name
                        isShowingRenameAlert = true
                    }) {
                        Label("Rename Album", systemImage: "pencil")
                    }

                    if !albumItems.isEmpty {
                        Button(action: { isSelectionMode.toggle() }) {
                            Label(isSelectionMode ? "Done" : "Select", systemImage: "checkmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.neonCyan)
                }
            }

            ToolbarItemGroup(placement: .bottomBar) {
                if isSelectionMode && !selectedItemIDs.isEmpty {
                    Button(role: .destructive, action: removeSelectedFromAlbum) {
                        Label("Remove from Album", systemImage: "minus.circle")
                    }
                    .foregroundColor(.neonCoral)
                }
            }
        }
        .alert("Rename Album", isPresented: $isShowingRenameAlert) {
            TextField("Album Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                var meta = appState.metadata
                _ = appState.environment.albumService.renameAlbum(id: album.id, newName: renameText, in: &meta)
                appState.metadata = meta
                Task { await appState.saveMetadata() }
            }
        }
        .navigationDestination(item: $selectedItemForDetail) { item in
            MediaDetailView(item: item) { deletedItem in
                // Handle deletion
                var meta = appState.metadata
                meta.items.removeAll(where: { $0.id == deletedItem.id })
                appState.metadata = meta
                Task { await appState.saveMetadata() }
            }
        }
    }

    private func removeSelectedFromAlbum() {
        var meta = appState.metadata
        appState.environment.albumService.removeMedia(
            itemIDs: selectedItemIDs,
            fromAlbumID: album.id,
            in: &meta
        )
        appState.metadata = meta
        Task { await appState.saveMetadata() }
        isSelectionMode = false
        selectedItemIDs.removeAll()
        appState.showToast("Removed from album", type: .info)
    }
}
