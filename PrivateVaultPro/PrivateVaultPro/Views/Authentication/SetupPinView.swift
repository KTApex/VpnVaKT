//
//  SetupPinView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct SetupPinView: View {
    @EnvironmentObject private var appState: AppState

    @State private var step: SetupStep = .enterPin
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var errorMessage: String? = nil

    private enum SetupStep {
        case enterPin
        case confirmPin
    }

    public var body: some View {
        ZStack {
            Color.vaultGradient.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Header Icon
                ZStack {
                    Circle()
                        .fill(Color.neonCyan.opacity(0.12))
                        .frame(width: 88, height: 88)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(Color.shieldActiveGradient)
                }

                VStack(spacing: 8) {
                    Text(step == .enterPin ? "Create Master PIN" : "Confirm Master PIN")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(step == .enterPin
                         ? "This PIN will be used as a secure fallback if biometrics are unavailable."
                         : "Re-enter the 4-digit PIN to verify.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.neonCoral)
                        .transition(.opacity)
                }

                if step == .enterPin {
                    PinEntryView(pin: $pin, maxDigits: 4) { entered in
                        withAnimation {
                            step = .confirmPin
                            errorMessage = nil
                        }
                    }
                } else {
                    PinEntryView(pin: $confirmPin, maxDigits: 4) { confirmed in
                        handlePinConfirmation(confirmed)
                    }
                }

                if step == .confirmPin {
                    Button("Back to PIN Entry") {
                        withAnimation {
                            pin = ""
                            confirmPin = ""
                            errorMessage = nil
                            step = .enterPin
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.neonCyan)
                }

                Spacer()
            }
            .padding()
        }
    }

    private func handlePinConfirmation(_ confirmed: String) {
        if confirmed == pin {
            do {
                try appState.environment.authService.setupPIN(confirmed)
                var updated = appState.settings
                updated.hasCompletedSetup = true
                appState.updateSettings(updated)
                appState.unlock()
                appState.showToast("Master PIN configured successfully!", type: .success)
            } catch {
                errorMessage = error.localizedDescription
                confirmPin = ""
            }
        } else {
            errorMessage = "PINs do not match. Please try again."
            HapticFeedback.notification(.error)
            confirmPin = ""
        }
    }
}
