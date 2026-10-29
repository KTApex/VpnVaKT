//
//  MetricCardView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct MetricCardView: View {
    public let title: String
    public let value: String
    public let icon: String
    public let accentColor: Color

    public var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentColor)
                    Spacer()
                }

                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
    }
}
