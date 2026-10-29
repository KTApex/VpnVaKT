//
//  GalleryView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI
import PhotosUI

public struct GalleryView: View {
    @EnvironmentObject private var appState: AppState

    @State private var selectedFilter: GalleryFilter = .all
    @State private var searchText: String = ""
    @State private var isSearchVisible: Bool = false
    @State private var isSelectionMode: Bool = false
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var selectedItemForDetail: MediaItem? = nil
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var isShowingDeleteConfirm: Bool = false
    @State private var isShowingBatchAlbumSheet: Bool = false

    private var filteredItems: [MediaItem] {
        var items = appState.metadata.items

        // 1. Filter by category
        switch selectedFilter {
        case .all:
            break
        case .photos:
            items = items.filter { $0.mediaType == .photo }
        case .videos:
            items = items.filter { $0.mediaType == .video }
        case .favorites:
            items = items.filter { $0.isFavorite }
        case .recent:
            let recentThreshold = Date().addingTimeInterval(-7 * 24 * 3600)
            items = items.filter { $0.importedDate >= recentThreshold }
        }

        // 2. Filter by search query
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            items = items.filter {
                $0.originalFilename.lowercased().contains(query) ||
                $0.creationDate.relativeOrFormattedString.lowercased().contains(query) ||
                $0.mediaType.displayName.lowercased().contains(query)
            }
        }

        return items
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.vaultGradient.ignoresSafeArea()

                VStack(spacing: 8) {
                    // Filter bar
                    FilterBarView(selectedFilter: $selectedFilter)

                    // Optional search bar
                    if isSearchVisible {
                        SearchBarView(searchText: $searchText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Gallery Grid or Empty State
                    if filteredItems.isEmpty {
                        emptyStateView
                    } else {
                        MediaGridView(
                            items: filteredItems,
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
            }
            .navigationTitle("Vault Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSelectionMode {
                        Button("Cancel") {
                            withAnimation {
                                isSelectionMode = false
                                selectedItemIDs.removeAll()
                            }
                        }
                        .foregroundColor(.neonCyan)
                    } else {
                        Button(action: {
                            withAnimation { isSearchVisible.toggle() }
                        }) {
                            Image(systemName: isSearchVisible ? "magnifyingglass.circle.fill" : "magnifyingglass")
                                .foregroundColor(isSearchVisible ? .neonCyan : .white)
                        }
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !isSelectionMode {
                        Menu {
                            Section("Grid Density") {
                                Button("2 Columns") { appState.settings.gridColumnCount = 2 }
                                Button("3 Columns") { appState.settings.gridColumnCount = 3 }
                                Button("4 Columns") { appState.settings.gridColumnCount = 4 }
                            }
                        } label: {
                            Image(systemName: "square.grid.3x3")
                                .foregroundColor(.white)
                        }

                        if !filteredItems.isEmpty {
                            Button("Select") {
                                withAnimation { isSelectionMode = true }
                            }
                            .foregroundColor(.neonCyan)
                        }

                        PhotosPicker(
                            selection: $selectedPickerItems,
                            matching: .any(of: [.images, .videos]),
                            photoLibrary: .shared()
                        ) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.neonCyan)
                        }
                    } else {
                        Text("\(selectedItemIDs.count) Selected")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    if isSelectionMode {
                        batchSelectionBottomBar
                    }
                }
            }
            .onChange(of: selectedPickerItems) { _, items in
                guard !items.isEmpty else { return }
                importPickerItems(items)
            }
            .navigationDestination(item: $selectedItemForDetail) { item in
                MediaDetailView(item: item) { deletedItem in
                    deleteSingleItem(deletedItem)
                }
            }
            .sheet(isPresented: $isShowingBatchAlbumSheet) {
                batchAddToAlbumSheetView
                    .presentationDetents([.medium])
                    .presentationBackground(Color.vaultDeepNavy)
            }
            .confirmationDialog(
                "Delete \(selectedItemIDs.count) items?",
                isPresented: $isShowingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete permanently", role: .destructive) {
                    deleteSelectedItems()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Selected media will be completely unlinked and erased from encrypted storage.")
            }
        }
    }

    // MARK: - Batch Bottom Bar

    private var batchSelectionBottomBar: some View {
        HStack {
            Button(action: { isShowingBatchAlbumSheet = true }) {
                Label("Add to Album", systemImage: "rectangle.stack.badge.plus")
            }
            .disabled(selectedItemIDs.isEmpty)

            Spacer()

            Button(action: batchToggleFavorite) {
                Label("Favorite", systemImage: "heart")
            }
            .disabled(selectedItemIDs.isEmpty)

            Spacer()

            Button(role: .destructive, action: { isShowingDeleteConfirm = true }) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(selectedItemIDs.isEmpty)
        }
        .foregroundColor(.neonCyan)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.vaultSurface)
                    .frame(width: 80, height: 80)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 34))
                    .foregroundColor(.white.opacity(0.4))
            }

            Text("No Media Found")
                .font(.headline)
                .foregroundColor(.white)

            Text("Import private photos and videos directly into your hardware-backed encrypted vault.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            PhotosPicker(
                selection: $selectedPickerItems,
                matching: .any(of: [.images, .videos]),
                photoLibrary: .shared()
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Import Media")
                }
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

    // MARK: - Batch Album Sheet

    private var batchAddToAlbumSheetView: some View {
        NavigationStack {
            List {
                if appState.metadata.albums.isEmpty {
                    Text("No albums exist yet. Create an album first.")
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    ForEach(appState.metadata.albums) { album in
                        Button(action: {
                            var meta = appState.metadata
                            appState.environment.albumService.addMedia(
                                itemIDs: selectedItemIDs,
                                toAlbumID: album.id,
                                in: &meta
                            )
                            appState.metadata = meta
                            Task { await appState.saveMetadata() }
                            isShowingBatchAlbumSheet = false
                            isSelectionMode = false
                            selectedItemIDs.removeAll()
                            appState.showToast("Added items to \(album.name)", type: .success)
                        }) {
                            HStack {
                                Image(systemName: "rectangle.stack.fill")
                                    .foregroundColor(.neonCyan)
                                Text(album.name)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.vaultDeepNavy)
            .navigationTitle("Add Selected to Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { isShowingBatchAlbumSheet = false }
                        .foregroundColor(.neonCyan)
                }
            }
        }
    }

    // MARK: - Actions

    private func importPickerItems(_ items: [PhotosPickerItem]) {
        Task {
            appState.isLoading = true
            appState.loadingText = "Encrypting & Importing..."
            var meta = appState.metadata
            do {
                let result = try await appState.environment.mediaImportService.importPhotosPickerItems(
                    items,
                    into: &meta,
                    deleteOriginals: appState.settings.askToDeleteOriginals,
                    progressHandler: nil
                )
                appState.metadata = meta
                selectedPickerItems.removeAll()
                appState.isLoading = false
                appState.showToast("Imported \(result.importedItems.count) media items", type: .success)
            } catch {
                appState.isLoading = false
                selectedPickerItems.removeAll()
                appState.showToast("Import error: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func deleteSingleItem(_ item: MediaItem) {
        Task {
            try? await appState.environment.vaultStorage.deleteMedia(item: item)
            var meta = appState.metadata
            meta.items.removeAll(where: { $0.id == item.id })
            meta.activityLogs.insert(
                ActivityLogEntry(actionType: .mediaDeleted, summary: "Deleted 1 encrypted item"),
                at: 0
            )
            appState.metadata = meta
            await appState.saveMetadata()
            appState.showToast("Item deleted", type: .info)
        }
    }

    private func deleteSelectedItems() {
        Task {
            let idsToDelete = selectedItemIDs
            var meta = appState.metadata
            let itemsToDelete = meta.items.filter { idsToDelete.contains($0.id) }

            for item in itemsToDelete {
                try? await appState.environment.vaultStorage.deleteMedia(item: item)
            }

            meta.items.removeAll(where: { idsToDelete.contains($0.id) })
            meta.activityLogs.insert(
                ActivityLogEntry(actionType: .mediaDeleted, summary: "Deleted \(itemsToDelete.count) encrypted items"),
                at: 0
            )
            appState.metadata = meta
            await appState.saveMetadata()

            withAnimation {
                isSelectionMode = false
                selectedItemIDs.removeAll()
            }
            appState.showToast("Deleted \(itemsToDelete.count) items", type: .info)
        }
    }

    private func batchToggleFavorite() {
        var meta = appState.metadata
        for id in selectedItemIDs {
            _ = appState.environment.albumService.toggleFavorite(itemID: id, in: &meta)
        }
        appState.metadata = meta
        Task { await appState.saveMetadata() }
        withAnimation {
            isSelectionMode = false
            selectedItemIDs.removeAll()
        }
        appState.showToast("Favorites updated", type: .success)
    }
}
