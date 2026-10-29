//
//  MainTabView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    public var body: some View {
        TabView(selection: $appState.selectedTab) {
            VaultDashboardView()
                .tabItem {
                    Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.iconName)
                }
                .tag(AppTab.dashboard)

            GalleryView()
                .tabItem {
                    Label(AppTab.gallery.title, systemImage: AppTab.gallery.iconName)
                }
                .tag(AppTab.gallery)

            AlbumsView()
                .tabItem {
                    Label(AppTab.albums.title, systemImage: AppTab.albums.iconName)
                }
                .tag(AppTab.albums)

            SettingsView()
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.iconName)
                }
                .tag(AppTab.settings)
        }
        .tint(.neonCyan)
    }
}
