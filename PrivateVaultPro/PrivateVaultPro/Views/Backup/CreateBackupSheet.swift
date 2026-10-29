//
//  CreateBackupSheet.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct CreateBackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isProcessing = false
    @State private var progressValue: Double = 0.0
    @State private var progressStatus: String = ""
    @State private var errorMessage: String? = nil
    @State private var generatedBackupURL: URL? = nil
    @State private var isShowingShareSheet = false

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.vaultDeepNavy.ignoresSafeArea()

                VStack(spacing: 24) {
                    if isProcessing {
                        processingView
                    } else if let backupURL = generatedBackupURL {
                        successView(url: backupURL)
                    } else {
                        configurationView
                    }
                }
                .padding()
            }
            .navigationTitle("Encrypted Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isProcessing {
                        Button("Close") { dismiss() }
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let url = generatedBackupURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    // MARK: - Configuration View

    private var configurationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.neonEmerald.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "lock.doc.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.neonEmerald)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Portable Encrypted ZIP")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Zero-knowledge AES-256 container")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Text("Enter a dedicated password to encrypt this backup archive. This password is never saved and is required to restore your data.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Backup Password (min. 6 characters)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        SecureField("Enter password", text: $password)
                            .padding()
                            .background(Color.vaultSurface)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Confirm Password")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        SecureField("Re-enter password", text: $confirmPassword)
                            .padding()
                            .background(Color.vaultSurface)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.neonCoral)
                }

                Button(action: startBackup) {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Generate Encrypted ZIP")
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(isInputValid ? Color.neonEmerald : Color.white.opacity(0.2))
                    .cornerRadius(14)
                }
                .disabled(!isInputValid)
                .padding(.top, 8)
            }
        }
    }

    private var isInputValid: Bool {
        password.count >= 6 && password == confirmPassword
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView(value: progressValue, total: 1.0)
                .tint(.neonEmerald)
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .padding(.horizontal, 40)

            Text(progressStatus)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            Text("Do not close the app during backup creation")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))

            Spacer()
        }
    }

    // MARK: - Success View

    private func successView(url: URL) -> some View {
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

            VStack(spacing: 6) {
                Text("Backup Created!")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.neonCyan)
                    .lineLimit(1)
            }

            Text("Your backup is securely encrypted and ready to be saved to Files, AirDropped, or sent via Share Sheet.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button(action: { isShowingShareSheet = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Share / Save to Files")
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.neonEmerald)
                    .cornerRadius(14)
                }

                Button("Done") { dismiss() }
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
    }

    // MARK: - Action

    private func startBackup() {
        guard isInputValid else { return }
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                var meta = appState.metadata
                let backupURL = try await appState.environment.backupService.createBackup(
                    password: password,
                    metadata: &meta
                ) { progress, status in
                    Task { @MainActor in
                        self.progressValue = progress
                        self.progressStatus = status
                    }
                }

                appState.metadata = meta
                self.generatedBackupURL = backupURL
                self.isProcessing = false
                HapticFeedback.notification(.success)
            } catch {
                self.isProcessing = false
                self.errorMessage = error.localizedDescription
                HapticFeedback.notification(.error)
            }
        }
    }
}
