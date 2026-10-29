//
//  VaultDashboardView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI
import PhotosUI

public struct VaultDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingCreateBackupSheet: Bool = false
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var isImporting: Bool = false
    @State private var importProgressMessage: String = ""

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.vaultGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Central VPN-inspired Status Ring
                        VaultStatusRingView(isUnlocked: appState.isUnlocked) {
                            if appState.isUnlocked {
                                appState.lock()
                            }
                        }
                        .padding(.vertical, 8)

                        // Main Action Button: LOCK VAULT or status
                        Button(action: {
                            HapticFeedback.impact(.medium)
                            if appState.isUnlocked {
                                appState.lock()
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("LOCK VAULT NOW")
                                    .font(.system(size: 15, weight: .bold))
                                    .tracking(0.5)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.vaultSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 20)

                        // Metrics Grid: Photos, Videos, Storage, Security
                        metricsGrid
                            .padding(.horizontal, 20)

                        // Quick Actions Bar
                        quickActionsSection
                            .padding(.horizontal, 20)

                        // Recent Activity (Sanitized, no sensitive media names)
                        recentActivitySection
                            .padding(.horizontal, 20)

                        // Architectural / Offline Guarantee Badge
                        offlineGuaranteeFooter
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.checkerboard")
                            .foregroundColor(.neonCyan)
                        Text("PrivateVault Pro")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(
                        selection: $selectedPickerItems,
                        matching: .any(of: [.images, .videos]),
                        photoLibrary: .shared()
                    ) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.shieldActiveGradient)
                    }
                    .onChange(of: selectedPickerItems) { _, newItems in
                        guard !newItems.isEmpty else { return }
                        handleImport(newItems)
                    }
                }
            }
            .sheet(isPresented: $isShowingCreateBackupSheet) {
                CreateBackupSheet()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.isUnlocked ? Color.neonEmerald : Color.neonCoral)
                        .frame(width: 8, height: 8)
                        .glow(color: appState.isUnlocked ? .neonEmerald : .neonCoral, radius: 6)

                    Text(appState.isUnlocked ? "VAULT UNLOCKED & ACTIVE" : "VAULT ENCRYPTED")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(appState.isUnlocked ? .neonEmerald : .white.opacity(0.6))
                }

                Text("Privacy Dashboard")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Spacer()

            // Biometric hardware badge
            HStack(spacing: 6) {
                Image(systemName: appState.environment.authService.biometryType.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(.neonCyan)

                Text(appState.environment.authService.biometryType.rawValue)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.vaultSurface)
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            MetricCardView(
                title: "Photos",
                value: "\(appState.metadata.photoCount)",
                icon: "photo.fill",
                accentColor: .neonCyan
            )

            MetricCardView(
                title: "Videos",
                value: "\(appState.metadata.videoCount)",
                icon: "video.fill",
                accentColor: .neonCoral
            )

            MetricCardView(
                title: "Vault Storage",
                value: ByteCountFormatter.formatBytes(appState.metadata.totalStorageBytes),
                icon: "internaldrive.fill",
                accentColor: .neonEmerald
            )

            MetricCardView(
                title: "Albums",
                value: "\(appState.metadata.albums.count)",
                icon: "rectangle.stack.fill",
                accentColor: .neonAmber
            )
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        GlassCard(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text("QUICK ACTIONS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.5))

                HStack(spacing: 12) {
                    QuickActionButton(
                        title: "Gallery",
                        icon: "photo.stack.fill",
                        color: .neonCyan
                    ) {
                        appState.selectedTab = .gallery
                    }

                    QuickActionButton(
                        title: "Albums",
                        icon: "rectangle.stack.fill",
                        color: .neonAmber
                    ) {
                        appState.selectedTab = .albums
                    }

                    QuickActionButton(
                        title: "New Backup",
                        icon: "arrow.down.doc.fill",
                        color: .neonEmerald
                    ) {
                        isShowingCreateBackupSheet = true
                    }

                    QuickActionButton(
                        title: "Settings",
                        icon: "gearshape.fill",
                        color: .white.opacity(0.8)
                    ) {
                        appState.selectedTab = .settings
                    }
                }
            }
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        GlassCard(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("VAULT ACTIVITY")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("Zero Content Leaks")
                        .font(.caption2)
                        .foregroundColor(.neonEmerald)
                }

                if appState.metadata.activityLogs.isEmpty {
                    Text("No recent activity. All operations remain strictly private.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 10) {
                        ForEach(appState.metadata.activityLogs.prefix(5)) { log in
                            HStack(spacing: 12) {
                                Image(systemName: log.actionType.systemIcon)
                                    .font(.system(size: 14))
                                    .foregroundColor(.neonCyan)
                                    .frame(width: 24)

                                Text(log.summary)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)

                                Spacer()

                                Text(log.timestamp.timeAgoString)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            if log.id != appState.metadata.activityLogs.prefix(5).last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.06))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Offline Guarantee Footer

    private var offlineGuaranteeFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.neonEmerald)
                .font(.system(size: 14))

            Text("Fully Offline • AES-GCM-256 Authenticated • No Telemetry")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Import Handler

    private func handleImport(_ items: [PhotosPickerItem]) {
        Task {
            isImporting = true
            appState.isLoading = true
            appState.loadingText = "Encrypting & Importing..."

            do {
                var meta = appState.metadata
                let result = try await appState.environment.mediaImportService.importPhotosPickerItems(
                    items,
                    into: &meta,
                    deleteOriginals: appState.settings.askToDeleteOriginals,
                    progressHandler: { progress in
                        // Handled
                    }
                )

                appState.metadata = meta
                selectedPickerItems.removeAll()
                appState.isLoading = false
                isImporting = false

                if result.duplicatesSkipped > 0 {
                    appState.showToast("Imported \(result.importedItems.count) items (\(result.duplicatesSkipped) duplicates skipped)", type: .info)
                } else {
                    appState.showToast("Imported \(result.importedItems.count) items into encrypted vault", type: .success)
                }
            } catch {
                appState.isLoading = false
                isImporting = false
                appState.showToast("Import failed: \(error.localizedDescription)", type: .error)
            }
        }
    }
}
