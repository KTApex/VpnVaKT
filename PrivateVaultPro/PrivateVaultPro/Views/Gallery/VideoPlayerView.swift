//
//  VideoPlayerView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI
import AVKit

public struct VideoPlayerView: View {
    public let item: MediaItem
    public let vaultStorage: VaultStorageServiceProtocol

    @State private var player: AVPlayer? = nil
    @State private var tempVideoURL: URL? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.neonCyan)
                    Text("Decrypting stream...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.neonCoral)
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .task {
            await preparePlayer()
        }
        .onDisappear {
            cleanupTempVideo()
        }
    }

    private func preparePlayer() async {
        do {
            let url = try await vaultStorage.createTemporaryDecryptedURL(for: item)
            self.tempVideoURL = url
            self.player = AVPlayer(url: url)
            self.isLoading = false
        } catch {
            self.errorMessage = "Failed to stream encrypted video: \(error.localizedDescription)"
            self.isLoading = false
        }
    }

    private func cleanupTempVideo() {
        player?.pause()
        player = nil
        if let url = tempVideoURL {
            try? FileManager.default.removeItem(at: url)
            tempVideoURL = nil
        }
    }
}
