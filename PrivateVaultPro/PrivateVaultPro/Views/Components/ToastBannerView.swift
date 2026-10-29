//
//  ToastBannerView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct ToastBannerView: View {
    public let message: ToastMessage

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: message.type.icon)
                .foregroundColor(message.type.color)
                .font(.system(size: 16, weight: .bold))

            Text(message.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color(red: 0.12, green: 0.15, blue: 0.22))
                .overlay(
                    Capsule()
                        .stroke(message.type.color.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
