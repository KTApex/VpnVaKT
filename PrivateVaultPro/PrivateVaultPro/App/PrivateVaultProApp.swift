//
//  PrivateVaultProApp.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

@main
struct PrivateVaultProApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environmentObject(appState)
        }
    }
}
