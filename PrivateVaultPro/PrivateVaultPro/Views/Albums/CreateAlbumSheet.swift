//
//  CreateAlbumSheet.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct CreateAlbumSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var albumName: String = ""

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.vaultDeepNavy.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Album Name")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        TextField("e.g. Personal, Financial, Travel", text: $albumName)
                            .padding()
                            .background(Color.vaultSurface)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)

                    Spacer()
                }
            }
            .navigationTitle("New Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveAlbum()
                    }
                    .font(.headline)
                    .foregroundColor(albumName.trimmingCharacters(in: .whitespaces).isEmpty ? .white.opacity(0.3) : .neonCyan)
                    .disabled(albumName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveAlbum() {
        var meta = appState.metadata
        let newAlbum = appState.environment.albumService.createAlbum(name: albumName, in: &meta)
        appState.metadata = meta
        Task { await appState.saveMetadata() }
        appState.showToast("Album '\(newAlbum.name)' created", type: .success)
        dismiss()
    }
}
