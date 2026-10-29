//
//  PinEntryView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct PinEntryView: View {
    @Binding public var pin: String
    public let maxDigits: Int
    public let onComplete: (String) -> Void
    public let onBiometricTap: (() -> Void)?
    public let biometryIcon: String?

    public init(
        pin: Binding<String>,
        maxDigits: Int = 4,
        onComplete: @escaping (String) -> Void,
        onBiometricTap: (() -> Void)? = nil,
        biometryIcon: String? = nil
    ) {
        self._pin = pin
        self.maxDigits = maxDigits
        self.onComplete = onComplete
        self.onBiometricTap = onBiometricTap
        self.biometryIcon = biometryIcon
    }

    private let keypadRows: [[KeypadItem]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.biometric, .digit("0"), .delete]
    ]

    private enum KeypadItem {
        case digit(String)
        case biometric
        case delete
    }

    public var body: some View {
        VStack(spacing: 28) {
            // PIN Dots Indicator
            HStack(spacing: 16) {
                ForEach(0..<maxDigits, id: \.self) { index in
                    Circle()
                        .fill(index < pin.count ? Color.neonCyan : Color.white.opacity(0.15))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(index < pin.count ? Color.neonCyan : Color.clear, lineWidth: 1)
                                .scaleEffect(index < pin.count ? 1.3 : 1.0)
                        )
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pin.count)
                }
            }
            .padding(.vertical, 8)

            // Custom Keypad Grid
            VStack(spacing: 16) {
                ForEach(keypadRows, id: \.self.description) { row in
                    HStack(spacing: 28) {
                        ForEach(row, id: \.self.description) { item in
                            keypadButton(for: item)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keypadButton(for item: KeypadItem) -> some View {
        Button(action: {
            handleKeypadPress(item)
        }) {
            ZStack {
                Circle()
                    .fill(Color.vaultSurface.opacity(0.8))
                    .frame(width: 74, height: 74)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                switch item {
                case .digit(let digit):
                    Text(digit)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                case .biometric:
                    if let icon = biometryIcon, onBiometricTap != nil {
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.neonCyan)
                    }
                case .delete:
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .disabled(itemDisabled(item))
        .opacity(itemDisabled(item) ? 0.0 : 1.0)
        .withHapticOnTap(.light)
    }

    private func handleKeypadPress(_ item: KeypadItem) {
        switch item {
        case .digit(let d):
            if pin.count < maxDigits {
                pin.append(d)
                if pin.count == maxDigits {
                    onComplete(pin)
                }
            }
        case .delete:
            if !pin.isEmpty {
                pin.removeLast()
            }
        case .biometric:
            onBiometricTap?()
        }
    }

    private func itemDisabled(_ item: KeypadItem) -> Bool {
        if case .biometric = item {
            return onBiometricTap == nil || biometryIcon == nil
        }
        return false
    }
}

extension PinEntryView.KeypadItem: CustomStringConvertible {
    var description: String {
        switch self {
        case .digit(let s): return s
        case .biometric: return "bio"
        case .delete: return "del"
        }
    }
}
