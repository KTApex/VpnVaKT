//
//  SecuritySettingsView.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import SwiftUI

public struct SecuritySettingsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var isShowingChangePinSheet = false
    @State private var oldPin = ""
    @State private var newPin = ""
    @State private var confirmNewPin = ""
    @State private var changePinError: String? = nil

    public var body: some View {
        ZStack {
            Color.vaultGradient.ignoresSafeArea()

            List {
                Section(header: Text("BIOMETRIC ACCESS").foregroundColor(.white.opacity(0.5))) {
                    Toggle(
                        "Enable \(appState.environment.authService.biometryType.rawValue)",
                        isOn: Binding(
                            get: { appState.settings.isBiometricsEnabled },
                            set: { newValue in
                                var s = appState.settings
                                s.isBiometricsEnabled = newValue
                                appState.updateSettings(s)
                            }
                        )
                    )
                    .tint(.neonCyan)

                    Toggle(
                        "Prompt on App Launch",
                        isOn: Binding(
                            get: { appState.settings.requireBiometricsOnLaunch },
                            set: { newValue in
                                var s = appState.settings
                                s.requireBiometricsOnLaunch = newValue
                                appState.updateSettings(s)
                            }
                        )
                    )
                    .tint(.neonCyan)
                }
                .listRowBackground(Color.vaultSurface)

                Section(header: Text("AUTO-LOCK PROTECTION").foregroundColor(.white.opacity(0.5))) {
                    Picker(
                        "Lock After Backgrounding",
                        selection: Binding(
                            get: { appState.settings.autoLockTimeout },
                            set: { newValue in
                                var s = appState.settings
                                s.autoLockTimeout = newValue
                                appState.updateSettings(s)
                            }
                        )
                    ) {
                        ForEach(AutoLockTimeout.allCases, id: \.rawValue) { timeout in
                            Text(timeout.title).tag(timeout)
                        }
                    }
                }
                .listRowBackground(Color.vaultSurface)

                Section(header: Text("MASTER PIN").foregroundColor(.white.opacity(0.5))) {
                    Button("Change Master PIN") {
                        isShowingChangePinSheet = true
                    }
                    .foregroundColor(.neonCyan)
                }
                .listRowBackground(Color.vaultSurface)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Security & Lock")
        .sheet(isPresented: $isShowingChangePinSheet) {
            changePinSheetView
                .presentationDetents([.medium])
                .presentationBackground(Color.vaultDeepNavy)
        }
    }

    private var changePinSheetView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let error = changePinError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.neonCoral)
                }

                SecureField("Current 4-digit PIN", text: $oldPin)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color.vaultSurface)
                    .cornerRadius(12)
                    .foregroundColor(.white)

                SecureField("New 4-digit PIN", text: $newPin)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color.vaultSurface)
                    .cornerRadius(12)
                    .foregroundColor(.white)

                SecureField("Confirm New 4-digit PIN", text: $confirmNewPin)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color.vaultSurface)
                    .cornerRadius(12)
                    .foregroundColor(.white)

                Button("Save New PIN") {
                    guard newPin.count >= 4 && newPin == confirmNewPin else {
                        changePinError = "New PIN must be 4 digits and match confirmation."
                        return
                    }
                    do {
                        let ok = try appState.environment.authService.changePIN(oldPIN: oldPin, newPIN: newPin)
                        if ok {
                            isShowingChangePinSheet = false
                            oldPin = ""
                            newPin = ""
                            confirmNewPin = ""
                            changePinError = nil
                            appState.showToast("Master PIN changed successfully", type: .success)
                        }
                    } catch {
                        changePinError = error.localizedDescription
                    }
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.neonCyan)
                .cornerRadius(12)

                Spacer()
            }
            .padding()
            .navigationTitle("Change PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isShowingChangePinSheet = false }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}
