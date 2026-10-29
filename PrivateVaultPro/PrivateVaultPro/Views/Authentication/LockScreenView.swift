//
//  LockScreenView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct LockScreenView: View {
    @EnvironmentObject private var appState: AppState

    @State private var pin: String = ""
    @State private var isShowingPinSheet: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isPulsing: Bool = false

    public var body: some View {
        ZStack {
            Color.vaultGradient.ignoresSafeArea()

            VStack(spacing: 36) {
                // App Brand Header
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.neonCyan)

                        Text("PrivateVault Pro")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Text("LOCAL HARDWARE-BACKED ENCRYPTION")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.5)
                        .foregroundColor(.neonCyan.opacity(0.8))
                }
                .padding(.top, 40)

                Spacer()

                // VPN-Inspired Status Ring
                ZStack {
                    // Outer subtle glowing aura
                    Circle()
                        .stroke(Color.white.opacity(0.04), lineWidth: 32)
                        .frame(width: 240, height: 240)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 210, height: 210)

                    // Inner circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.vaultSurface, Color(red: 0.05, green: 0.08, blue: 0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 190, height: 190)
                        .shadow(color: Color.black.opacity(0.5), radius: 15, x: 0, y: 10)

                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .scaleEffect(isPulsing ? 1.05 : 0.98)
                            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isPulsing)

                        Text("VAULT LOCKED")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .onAppear {
                    isPulsing = true
                }

                // Biometric Status Tag
                HStack(spacing: 8) {
                    Image(systemName: appState.environment.authService.biometryType.iconName)
                        .foregroundColor(.neonCyan)
                    Text("\(appState.environment.authService.biometryType.rawValue) Protected")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.vaultSurface)
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )

                Spacer()

                // Primary Unlock Action
                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            HapticFeedback.impact(.medium)
                            if appState.settings.isBiometricsEnabled && appState.environment.authService.biometryType != .none {
                                do {
                                    let success = try await appState.environment.authService.authenticateWithBiometrics()
                                    if success {
                                        appState.unlock()
                                    } else {
                                        isShowingPinSheet = true
                                    }
                                } catch {
                                    isShowingPinSheet = true
                                }
                            } else {
                                isShowingPinSheet = true
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 18, weight: .bold))

                            Text("OPEN VAULT")
                                .font(.system(size: 17, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            LinearGradient(
                                colors: [Color.neonCyan, Color.neonEmerald],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(18)
                        .glow(color: .neonCyan, radius: 14, opacity: 0.4)
                    }
                    .padding(.horizontal, 24)

                    Button("Unlock with Master PIN") {
                        isShowingPinSheet = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $isShowingPinSheet) {
            pinSheetView
                .presentationDetents([.fraction(0.7)])
                .presentationBackground(Color.vaultDeepNavy)
        }
    }

    private var pinSheetView: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button(action: {
                    isShowingPinSheet = false
                    pin = ""
                    errorMessage = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)

            Text("Enter Master PIN")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            if let error = errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.neonCoral)
            }

            PinEntryView(
                pin: $pin,
                maxDigits: 4,
                onComplete: { entered in
                    if appState.environment.authService.authenticateWithPIN(entered) {
                        isShowingPinSheet = false
                        pin = ""
                        errorMessage = nil
                        appState.unlock()
                    } else {
                        HapticFeedback.notification(.error)
                        errorMessage = "Incorrect PIN"
                        pin = ""
                    }
                },
                onBiometricTap: {
                    Task {
                        if let success = try? await appState.environment.authService.authenticateWithBiometrics(), success {
                            isShowingPinSheet = false
                            pin = ""
                            appState.unlock()
                        }
                    }
                },
                biometryIcon: appState.environment.authService.biometryType.iconName
            )

            Spacer()
        }
        .padding()
    }
}
