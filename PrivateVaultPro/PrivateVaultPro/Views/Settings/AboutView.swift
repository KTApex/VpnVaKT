//
//  AboutView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct AboutView: View {
    public var body: some View {
        ZStack {
            Color.vaultGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.shieldActiveGradient)

                        Text("PrivateVault Pro")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Version 1.0.0 (Build 2026.10)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 20)

                    GlassCard(cornerRadius: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("CORE PRIVACY PRINCIPLES")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(.white.opacity(0.5))

                            principleRow(
                                icon: "network.slash",
                                title: "100% Offline & Private",
                                description: "No server requests, no telemetry, no tracking, and no third-party SDKs."
                            )

                            principleRow(
                                icon: "key.horizontal.fill",
                                title: "Hardware-Backed Security",
                                description: "Encryption keys are generated on-device and sealed in the iOS Secure Enclave / Keychain."
                            )

                            principleRow(
                                icon: "lock.fill",
                                title: "Zero Content Leaks",
                                description: "Media files are encrypted before saving. Temporary files are unlinked and cleaned immediately."
                            )

                            principleRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Open Portable Backups",
                                description: "Password-derived AES-GCM ZIP backups that you own and can restore anywhere without lock-in."
                            )
                        }
                    }

                    Text("Designed with Apple Photos simplicity and VPN-grade aesthetic.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
                .padding(16)
            }
        }
        .navigationTitle("About & Privacy")
    }

    private func principleRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.neonCyan)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}
