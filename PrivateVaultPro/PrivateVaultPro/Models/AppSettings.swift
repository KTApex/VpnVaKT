//
//  AppSettings.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation

public enum AutoLockTimeout: Int, Codable, CaseIterable, Sendable {
    case immediate = 0
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300
    case never = -1

    public var title: String {
        switch self {
        case .immediate: return "Immediately"
        case .thirtySeconds: return "30 seconds"
        case .oneMinute: return "1 minute"
        case .fiveMinutes: return "5 minutes"
        case .never: return "Never (Session only)"
        }
    }
}

public struct AppSettings: Codable, Sendable {
    public var autoLockTimeout: AutoLockTimeout
    public var isBiometricsEnabled: Bool
    public var themePreference: AppTheme
    public var gridColumnCount: Int
    public var askToDeleteOriginals: Bool
    public var requireBiometricsOnLaunch: Bool
    public var hasCompletedSetup: Bool

    public static let `default` = AppSettings(
        autoLockTimeout: .immediate,
        isBiometricsEnabled: true,
        themePreference: .dark,
        gridColumnCount: 3,
        askToDeleteOriginals: true,
        requireBiometricsOnLaunch: true,
        hasCompletedSetup: false
    )
}
