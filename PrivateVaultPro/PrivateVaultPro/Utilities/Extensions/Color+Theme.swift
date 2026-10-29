//
//  Color+Theme.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public extension Color {
    static let vaultBackground = Color("VaultBackground", bundle: nil).opacity(1.0)
    static let vaultCard = Color("VaultCard", bundle: nil)
    static let vaultCardBorder = Color.white.opacity(0.08)

    // Vibrant privacy neon accents
    static let neonCyan = Color(red: 0.0, green: 0.88, blue: 0.95)
    static let neonEmerald = Color(red: 0.06, green: 0.84, blue: 0.55)
    static let neonAmber = Color(red: 1.0, green: 0.65, blue: 0.15)
    static let neonCoral = Color(red: 1.0, green: 0.35, blue: 0.42)
    static let vaultDeepNavy = Color(red: 0.04, green: 0.07, blue: 0.12)
    static let vaultSurface = Color(red: 0.08, green: 0.12, blue: 0.18)

    static var vaultGradient: LinearGradient {
        LinearGradient(
            colors: [Color.vaultDeepNavy, Color(red: 0.02, green: 0.03, blue: 0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var shieldLockedGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.2, green: 0.25, blue: 0.35), Color(red: 0.1, green: 0.12, blue: 0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var shieldActiveGradient: LinearGradient {
        LinearGradient(
            colors: [Color.neonCyan, Color.neonEmerald],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
