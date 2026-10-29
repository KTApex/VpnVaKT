//
//  VaultStatusRingView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct VaultStatusRingView: View {
    public let isUnlocked: Bool
    public let onToggle: () -> Void

    @State private var rotationDegrees: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    public var body: some View {
        Button(action: {
            HapticFeedback.impact(.medium)
            onToggle()
        }) {
            ZStack {
                // Outer subtle glowing aura
                Circle()
                    .stroke(
                        isUnlocked
                            ? Color.neonEmerald.opacity(0.15)
                            : Color.white.opacity(0.04),
                        lineWidth: 24
                    )
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulseScale)

                // Animated glowing dash circle
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: isUnlocked
                                ? [Color.neonCyan, Color.neonEmerald, Color.neonCyan.opacity(0.2), Color.neonCyan]
                                : [Color.white.opacity(0.2), Color.white.opacity(0.05), Color.white.opacity(0.2)]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 12])
                    )
                    .frame(width: 190, height: 190)
                    .rotationEffect(.degrees(rotationDegrees))

                // Inner Glass Circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.vaultSurface, Color(red: 0.05, green: 0.08, blue: 0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)
                    .overlay(
                        Circle()
                            .stroke(
                                isUnlocked
                                    ? Color.neonEmerald.opacity(0.4)
                                    : Color.white.opacity(0.1),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: isUnlocked
                            ? Color.neonEmerald.opacity(0.3)
                            : Color.black.opacity(0.4),
                        radius: 20
                    )

                // Central Icon & Status
                VStack(spacing: 8) {
                    Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(
                            isUnlocked
                                ? Color.shieldActiveGradient
                                : LinearGradient(colors: [.white, .white.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        )

                    Text(isUnlocked ? "VAULT ACTIVE" : "VAULT LOCKED")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(isUnlocked ? .neonEmerald : .white.opacity(0.6))
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                rotationDegrees = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
    }
}
