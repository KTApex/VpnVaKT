//
//  MediaGridView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct MediaGridView: View {
    public let items: [MediaItem]
    public let columnCount: Int
    public let isSelectionMode: Bool
    @Binding public var selectedIDs: Set<UUID>
    public let onItemTap: (MediaItem) -> Void
    public let vaultStorage: VaultStorageServiceProtocol
    public let thumbnailService: ThumbnailServiceProtocol

    // Group items by date section
    private var groupedSections: [(date: String, items: [MediaItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item -> Date in
            calendar.startOfDay(for: item.creationDate)
        }
        let sortedDates = grouped.keys.sorted(by: >)
        return sortedDates.map { date in
            (date: date.relativeOrFormattedString, items: grouped[date] ?? [])
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: max(1, columnCount))
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(groupedSections, id: \.date) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.date)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(section.items) { item in
                                MediaThumbnailView(
                                    item: item,
                                    isSelected: selectedIDs.contains(item.id),
                                    isSelectionMode: isSelectionMode,
                                    vaultStorage: vaultStorage,
                                    thumbnailService: thumbnailService
                                )
                                .aspectRatio(1, contentMode: .fill)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    HapticFeedback.selection()
                                    if isSelectionMode {
                                        if selectedIDs.contains(item.id) {
                                            selectedIDs.remove(item.id)
                                        } else {
                                            selectedIDs.insert(item.id)
                                        }
                                    } else {
                                        onItemTap(item)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 60)
        }
    }
}
