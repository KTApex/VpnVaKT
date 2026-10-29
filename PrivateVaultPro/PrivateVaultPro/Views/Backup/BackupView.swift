//
//  BackupView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

public struct BackupView: View {
    @EnvironmentObject private var appState: AppState

    @State private var isShowingCreateSheet: Bool = false
    @State private var isShowingFileImporter: Bool = false
    @State private var selectedRestoreURL: URL? = nil
    @State private var isShowingRestorePreview: Bool = false

    public var body: some View {
        ZStack {
            Color.vaultGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    GlassCard(cornerRadius: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.system(size: 28))
                                    .foregroundColor(.neonCyan)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Encrypted Offline Backup")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Zero Cloud • 100% User Owned")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }

                            Text("PrivateVault backups are self-contained PKZip archives containing AES-256 encrypted payload and metadata. You can safely store them on a PC, external drive, or AirDrop to other iOS devices.")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    // Create Backup Action Card
                    GlassCard(cornerRadius: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("CREATE BACKUP")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                                if let last = appState.metadata.lastBackupDate {
                                    Text("Last: \(last.timeAgoString)")
                                        .font(.caption2)
                                        .foregroundColor(.neonEmerald)
                                }
                            }

                            Text("Export all \(appState.metadata.items.count) encrypted photos, videos, and albums into a password-protected ZIP archive.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))

                            Button(action: { isShowingCreateSheet = true }) {
                                HStack {
                                    Image(systemName: "arrow.down.doc.fill")
                                    Text("Create Encrypted Backup Now")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.neonCyan)
                                .cornerRadius(12)
                            }
                        }
                    }

                    // Import & Restore Action Card
                    GlassCard(cornerRadius: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("IMPORT & RESTORE")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(.white.opacity(0.5))

                            Text("Select an existing PrivateVault ZIP archive from the iOS Files app to preview and restore your media.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))

                            Button(action: { isShowingFileImporter = true }) {
                                HStack {
                                    Image(systemName: "arrow.up.doc.fill")
                                    Text("Import Backup from Files")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.vaultSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .cornerRadius(12)
                            }
                        }
                    }

                    // Technical Specifications
                    GlassCard(cornerRadius: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SECURITY SPECIFICATIONS")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(.white.opacity(0.5))

                            specRow(title: "Format Version", value: "v1.0 (PKZip standard)")
                            specRow(title: "KDF Algorithm", value: "PBKDF2-HMAC-SHA256 (100k rounds)")
                            specRow(title: "Cipher", value: "AES-GCM 256-bit Authenticated")
                            specRow(title: "Salt / Nonce", value: "Hardware Secure Random (CryptoKit)")
                            specRow(title: "Protection", value: "Zip Slip & Decompression Bomb Guard")
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Backup & Restore")
        .sheet(isPresented: $isShowingCreateSheet) {
            CreateBackupSheet()
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [UTType.zip, UTType.archive],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else {
                    appState.showToast("Cannot access selected file.", type: .error)
                    return
                }

                // Copy to local temporary folder for inspection
                let localTemp = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: localTemp)
                do {
                    try FileManager.default.copyItem(at: url, to: localTemp)
                    url.stopAccessingSecurityScopedResource()
                    self.selectedRestoreURL = localTemp
                    self.isShowingRestorePreview = true
                } catch {
                    url.stopAccessingSecurityScopedResource()
                    appState.showToast("Cannot copy backup archive: \(error.localizedDescription)", type: .error)
                }
            case .failure(let error):
                appState.showToast("Import cancelled: \(error.localizedDescription)", type: .info)
            }
        }
        .sheet(isPresented: $isShowingRestorePreview) {
            if let restoreURL = selectedRestoreURL {
                RestorePreviewSheet(backupFileURL: restoreURL)
            }
        }
    }

    private func specRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}
