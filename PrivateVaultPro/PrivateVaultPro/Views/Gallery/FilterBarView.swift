//
//  FilterBarView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public enum GalleryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case photos = "Photos"
    case videos = "Videos"
    case favorites = "Favorites"
    case recent = "Recently Added"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .photos: return "photo.fill"
        case .videos: return "video.fill"
        case .favorites: return "heart.fill"
        case .recent: return "clock.fill"
        }
    }
}

public struct FilterBarView: View {
    @Binding public var selectedFilter: GalleryFilter

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GalleryFilter.allCases) { filter in
                    let isSelected = (selectedFilter == filter)

                    Button(action: {
                        HapticFeedback.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = filter
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: filter.iconName)
                                .font(.system(size: 12, weight: .semibold))

                            Text(filter.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(isSelected ? .black : .white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.neonCyan : Color.vaultSurface)
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}
