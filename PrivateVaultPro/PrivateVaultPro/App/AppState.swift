//
//  AppState.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI
import Combine

public enum AppTab: Int, CaseIterable, Identifiable {
    case dashboard = 0
    case gallery = 1
    case albums = 2
    case settings = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .gallery: return "Gallery"
        case .albums: return "Albums"
        case .settings: return "Settings"
        }
    }

    public var iconName: String {
        switch self {
        case .dashboard: return "shield.lefthalf.filled"
        case .gallery: return "photo.stack.fill"
        case .albums: return "rectangle.stack.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public enum ToastType {
    case success
    case error
    case info

    public var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }

    public var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

public struct ToastMessage: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let type: ToastType

    public static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
public final class AppState: ObservableObject {
    @Published public var isUnlocked: Bool = false
    @Published public var isPrivacyBlurred: Bool = false
    @Published public var selectedTab: AppTab = .dashboard
    @Published public var metadata: VaultMetadata = VaultMetadata()
    @Published public var settings: AppSettings = .default
    @Published public var activeToast: ToastMessage?
    @Published public var isLoading: Bool = false
    @Published public var loadingText: String = ""

    public let environment: AppEnvironment
    private let settingsStorageKey = "com.privatevaultpro.settings_v1"

    public init(environment: AppEnvironment = .shared) {
        self.environment = environment
        loadSettings()
    }

    // MARK: - Lifecycle & Security

    public func appDidLaunch() async {
        await refreshMetadata()
        if !environment.authService.hasConfiguredPIN {
            // First time setup required
            isUnlocked = false
        } else if settings.requireBiometricsOnLaunch && settings.isBiometricsEnabled {
            await attemptBiometricUnlock()
        }
    }

    public func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            withAnimation(.easeInOut(duration: 0.2)) {
                isPrivacyBlurred = false
            }
            if environment.authService.shouldAutoLock(timeout: settings.autoLockTimeout) {
                lock()
            }
        case .inactive:
            // Blur immediately when entering multitasking / app switcher
            withAnimation(.easeInOut(duration: 0.15)) {
                isPrivacyBlurred = true
            }
        case .background:
            environment.authService.recordBackgroundTransition()
            withAnimation(.easeInOut(duration: 0.15)) {
                isPrivacyBlurred = true
            }
            if settings.autoLockTimeout == .immediate {
                lock()
            }
        @unknown default:
            break
        }
    }

    public func lock() {
        environment.authService.lock()
        environment.thumbnailService.clearMemoryCache()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isUnlocked = false
        }
    }

    public func unlock() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isUnlocked = true
        }
        Task {
            await refreshMetadata()
        }
    }

    public func attemptBiometricUnlock() async {
        guard settings.isBiometricsEnabled else { return }
        do {
            let success = try await environment.authService.authenticateWithBiometrics()
            if success {
                unlock()
            }
        } catch {
            // Biometrics cancelled or unavailable - remain locked for PIN entry
        }
    }

    // MARK: - Metadata & Data Refresh

    public func refreshMetadata() async {
        do {
            let loaded = try await environment.vaultStorage.loadMetadata()
            self.metadata = loaded
        } catch {
            // If fresh vault, leave default
        }
    }

    public func saveMetadata() async {
        do {
            try await environment.vaultStorage.saveMetadata(metadata)
        } catch {
            showToast("Failed to save changes", type: .error)
        }
    }

    // MARK: - Settings Persistence

    public func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
        saveSettings()
    }

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            try? environment.keychainService.save(key: settingsStorageKey, data: encoded)
        }
    }

    private func loadSettings() {
        if let data = try? environment.keychainService.load(key: settingsStorageKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        }
    }

    // MARK: - Toast Banner Helpers

    public func showToast(_ title: String, type: ToastType = .info) {
        withAnimation {
            self.activeToast = ToastMessage(title: title, type: type)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            withAnimation {
                if self.activeToast?.title == title {
                    self.activeToast = nil
                }
            }
        }
    }
}
