//
//  PrivacyBlurOverlay.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct PrivacyBlurOverlay: View {
    public var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.neonCyan)

                Text("PrivateVault Protected")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
}
