//
//  RootContainerView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct RootContainerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState

    public var body: some View {
        ZStack {
            // Main content depending on auth state
            if !appState.environment.authService.hasConfiguredPIN {
                SetupPinView()
            } else if !appState.isUnlocked {
                LockScreenView()
            } else {
                MainTabView()
            }

            // Privacy blur overlay when entering iOS App Switcher
            if appState.isPrivacyBlurred {
                PrivacyBlurOverlay()
                    .transition(.opacity)
                    .zIndex(100)
            }

            // Loading overlay
            if appState.isLoading {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.neonCyan)
                            .scaleEffect(1.5)
                        Text(appState.loadingText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .padding(28)
                    .background(Color.vaultSurface)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .transition(.opacity)
                .zIndex(90)
            }

            // Active Toast Banner
            if let toast = appState.activeToast {
                VStack {
                    ToastBannerView(message: toast)
                        .padding(.top, 10)
                    Spacer()
                }
                .zIndex(95)
            }
        }
        .preferredColorScheme(appState.settings.themePreference.colorScheme)
        .onChange(of: scenePhase) { _, newPhase in
            appState.handleScenePhaseChange(newPhase)
        }
        .task {
            await appState.appDidLaunch()
        }
    }
}
