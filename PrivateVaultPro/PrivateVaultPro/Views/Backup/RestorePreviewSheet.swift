//
//  RestorePreviewSheet.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct RestorePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    public let backupFileURL: URL

    @State private var password = ""
    @State private var stage: RestoreStage = .passwordPrompt
    @State private var previewData: RestorePreview? = nil
    @State private var decryptedPayload: DecryptedBackupPayload? = nil
    @State private var selectedStrategy: RestoreStrategy = .merge
    @State private var isShowingReplaceConfirmation = false
    @State private var errorMessage: String? = nil
    @State private var isRestoring = false

    private enum RestoreStage {
        case passwordPrompt
        case preview
        case complete
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.vaultDeepNavy.ignoresSafeArea()

                VStack(spacing: 20) {
                    switch stage {
                    case .passwordPrompt:
                        passwordEntrySection
                    case .preview:
                        previewSection
                    case .complete:
                        restorationCompleteSection
                    }
                }
                .padding()
            }
            .navigationTitle("Restore Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isRestoring {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .confirmationDialog(
                "Replace Entire Vault?",
                isPresented: $isShowingReplaceConfirmation,
                titleVisibility: .visible
            ) {
                Button("Erase & Replace Vault", role: .destructive) {
                    executeRestore()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently overwrite all existing media in this vault with the backup archive contents.")
            }
        }
    }

    // MARK: - Password Entry Section

    private var passwordEntrySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.neonCyan.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "key.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.neonCyan)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Enter Backup Password")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(backupFileURL.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Text("This backup is protected with AES-256 authenticated encryption. Enter the password that was used when creating the backup.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.7))

            SecureField("Password", text: $password)
                .padding()
                .background(Color.vaultSurface)
                .cornerRadius(12)
                .foregroundColor(.white)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))

            if let error = errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.neonCoral)
            }

            Button(action: verifyAndDecrypt) {
                HStack {
                    if isRestoring {
                        ProgressView().tint(.black)
                    } else {
                        Text("Decrypt & Verify Archive")
                    }
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(password.isEmpty ? Color.white.opacity(0.2) : Color.neonCyan)
                .cornerRadius(14)
            }
            .disabled(password.isEmpty || isRestoring)

            Spacer()
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 20) {
            if let preview = previewData {
                VStack(spacing: 8) {
                    Text("Restore Confirmation")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Restore \(preview.manifest.photoCount) Photos and \(preview.manifest.videoCount) Videos?")
                        .font(.subheadline)
                        .foregroundColor(.neonCyan)
                }

                GlassCard(cornerRadius: 16) {
                    VStack(spacing: 12) {
                        infoRow(title: "Archive Created", value: preview.manifest.createdAt.fullDateTimeString)
                        infoRow(title: "Photos Found", value: "\(preview.manifest.photoCount)")
                        infoRow(title: "Videos Found", value: "\(preview.manifest.videoCount)")
                        infoRow(title: "Albums Found", value: "\(preview.manifest.albumCount)")
                        infoRow(title: "Duplicates in Vault", value: "\(preview.duplicatesCount)")
                    }
                }

                // Strategy Picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Restoration Mode:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Picker("Strategy", selection: $selectedStrategy) {
                        Text("Merge (Keep Existing)").tag(RestoreStrategy.merge)
                        Text("Replace (Overwrite)").tag(RestoreStrategy.replace)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.top, 4)

                if let error = errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.neonCoral)
                }

                Button(action: {
                    if selectedStrategy == .replace {
                        isShowingReplaceConfirmation = true
                    } else {
                        executeRestore()
                    }
                }) {
                    HStack {
                        if isRestoring {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                            Text("Confirm & Restore")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.neonEmerald)
                    .cornerRadius(14)
                }
                .disabled(isRestoring)
            }

            Spacer()
        }
    }

    // MARK: - Restoration Complete

    private var restorationCompleteSection: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.neonEmerald.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.neonEmerald)
            }

            Text("Vault Restored Successfully")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("All media items, albums, and encrypted metadata have been verified and restored.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Done") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.neonEmerald)
            .cornerRadius(14)

            Spacer()
        }
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

    // MARK: - Actions

    private func verifyAndDecrypt() {
        isRestoring = true
        errorMessage = nil

        Task {
            do {
                let result = try appState.environment.restoreService.decryptAndPreview(
                    at: backupFileURL,
                    password: password,
                    existingMetadata: appState.metadata
                )

                self.decryptedPayload = result.payload
                self.previewData = result.preview
                self.isRestoring = false
                self.stage = .preview
                HapticFeedback.notification(.success)
            } catch {
                self.isRestoring = false
                self.errorMessage = error.localizedDescription
                HapticFeedback.notification(.error)
            }
        }
    }

    private func executeRestore() {
        guard let payload = decryptedPayload else { return }
        isRestoring = true
        errorMessage = nil

        Task {
            do {
                var meta = appState.metadata
                try await appState.environment.restoreService.executeRestore(
                    payload: payload,
                    strategy: selectedStrategy,
                    currentMetadata: &meta
                )

                appState.metadata = meta
                self.isRestoring = false
                self.stage = .complete
                HapticFeedback.notification(.success)
            } catch {
                self.isRestoring = false
                self.errorMessage = error.localizedDescription
                HapticFeedback.notification(.error)
            }
        }
    }
}
