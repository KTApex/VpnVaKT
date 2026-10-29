//
//  SettingsView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var isShowingClearCacheAlert = false
    @State private var isShowingDeleteAllAlert = false

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.vaultGradient.ignoresSafeArea()

                List {
                    // Security & Biometrics
                    Section(header: Text("SECURITY & AUTHENTICATION").foregroundColor(.white.opacity(0.5))) {
                        NavigationLink(destination: SecuritySettingsView()) {
                            HStack {
                                Image(systemName: "faceid")
                                    .foregroundColor(.neonCyan)
                                    .frame(width: 24)
                                Text("Biometrics & Auto-Lock")
                                Spacer()
                                Text(appState.settings.autoLockTimeout.title)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }

                        Toggle(
                            "Ask to Delete Originals after Import",
                            isOn: Binding(
                                get: { appState.settings.askToDeleteOriginals },
                                set: { val in
                                    var s = appState.settings
                                    s.askToDeleteOriginals = val
                                    appState.updateSettings(s)
                                }
                            )
                        )
                        .tint(.neonCyan)
                    }
                    .listRowBackground(Color.vaultSurface)

                    // Appearance & Grid
                    Section(header: Text("APPEARANCE").foregroundColor(.white.opacity(0.5))) {
                        Picker(
                            "Theme",
                            selection: Binding(
                                get: { appState.settings.themePreference },
                                set: { val in
                                    var s = appState.settings
                                    s.themePreference = val
                                    appState.updateSettings(s)
                                }
                            )
                        ) {
                            ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }

                        Picker(
                            "Gallery Columns",
                            selection: Binding(
                                get: { appState.settings.gridColumnCount },
                                set: { val in
                                    var s = appState.settings
                                    s.gridColumnCount = val
                                    appState.updateSettings(s)
                                }
                            )
                        ) {
                            Text("2 Columns").tag(2)
                            Text("3 Columns").tag(3)
                            Text("4 Columns").tag(4)
                        }
                    }
                    .listRowBackground(Color.vaultSurface)

                    // Backup & Restore
                    Section(header: Text("DATA MANAGEMENT").foregroundColor(.white.opacity(0.5))) {
                        NavigationLink(destination: BackupView()) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath.doc.fill")
                                    .foregroundColor(.neonEmerald)
                                    .frame(width: 24)
                                Text("Backup & Restore")
                                Spacer()
                                Text("v1.0 ZIP")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }

                        HStack {
                            Image(systemName: "internaldrive.fill")
                                .foregroundColor(.neonCyan)
                                .frame(width: 24)
                            Text("Encrypted Vault Storage")
                            Spacer()
                            Text(ByteCountFormatter.formatBytes(appState.metadata.totalStorageBytes))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Button(action: { isShowingClearCacheAlert = true }) {
                            HStack {
                                Image(systemName: "trash.circle")
                                    .foregroundColor(.neonAmber)
                                    .frame(width: 24)
                                Text("Clear Thumbnail Memory Cache")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .listRowBackground(Color.vaultSurface)

                    // About & Legal
                    Section(header: Text("ABOUT").foregroundColor(.white.opacity(0.5))) {
                        NavigationLink(destination: AboutView()) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.neonCyan)
                                    .frame(width: 24)
                                Text("Privacy Architecture & About")
                            }
                        }

                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0 (Offline Native)")
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .listRowBackground(Color.vaultSurface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .alert("Clear Thumbnail Cache?", isPresented: $isShowingClearCacheAlert) {
                Button("Clear Cache", role: .destructive) {
                    appState.environment.thumbnailService.clearMemoryCache()
                    appState.showToast("Thumbnail cache cleared", type: .info)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This frees temporary memory. Thumbnails will re-render automatically when browsing the gallery.")
            }
        }
    }
}
