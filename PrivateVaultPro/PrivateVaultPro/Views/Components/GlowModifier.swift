//
//  GlowModifier.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct GlowModifier: ViewModifier {
    public let color: Color
    public let radius: CGFloat
    public let opacity: Double

    public func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: radius / 2)
            .shadow(color: color.opacity(opacity * 0.7), radius: radius)
    }
}

public extension View {
    func glow(color: Color = .neonCyan, radius: CGFloat = 16, opacity: Double = 0.6) -> some View {
        self.modifier(GlowModifier(color: color, radius: radius, opacity: opacity))
    }
}
