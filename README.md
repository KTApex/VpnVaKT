# PrivateVault Pro — Premium iOS Privacy Vault

[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![CryptoKit AES-GCM](https://img.shields.io/badge/Cryptography-AES--256--GCM-brightgreen.svg)](https://developer.apple.com/documentation/cryptokit)
[![Offline Native](https://img.shields.io/badge/Privacy-100%25%20Offline-success.svg)](#privacy-guarantees)
[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-lightgrey.svg)]()

**PrivateVault Pro** combines the tactile, clean ON/OFF aesthetic of a modern VPN application with the rich browsing and organizational experience of Apple Photos. It provides hardware-backed local encryption for private photos and videos with zero third-party dependencies, zero telemetry, and zero mandatory cloud services.

---

## 🌟 Key Features

### 1. VPN-Inspired Dashboard
- **Central Dynamic Status Ring:** Glowing, animated vault status indicator displaying real-time cryptographic lock state.
- **Single-Tap Vault Lock / Unlock:** Seamlessly toggle the protection layer.
- **Biometric Integration Indicator:** Real-time Face ID / Touch ID / Optic ID enrollment status.
- **Metrics Grid:** Instant overview of protected photo count, video count, album count, and total encrypted storage bytes.
- **Sanitized Activity Log:** Displays operational events (e.g., *"Imported 4 secure items"*, *"Vault unlocked via Face ID"*) without exposing file names or thumbnails.
- **Strict Privacy Disclosure:** Clarifies local vault functionality—no fake VPN claims or deceptive network traffic rerouting.

### 2. Apple Photos-Inspired Private Gallery
- **Multi-Category Filtering:** Filter across **All Media**, **Photos**, **Videos**, **Favorites**, and **Recently Added**.
- **Dynamic Date Grouping:** Natural chronological sections (*"Today"*, *"Yesterday"*, *"October 2026"*).
- **Smooth Thumbnail Cache:** Two-tier caching with in-memory `NSCache` and on-disk encrypted thumbnails for high-framerate 120Hz ProMotion scrolling.
- **Full-Screen Media Viewer:** Double-tap zoom, continuous pinch-to-zoom (`MagnificationGesture`), and full security inspector sheet.
- **Native Video Playback:** Secure streaming playback directly into native `AVPlayer` with immediate purge of temporary decrypted playback files.
- **Multi-Selection Mode:** Batch operations for permanent deletion, favorite toggling, and album assignment.
- **Instant Search:** Real-time filtering by original filename, media type, and date.

### 3. Cryptographic Core
- **Apple CryptoKit Authenticated Encryption:** AES-256-GCM authenticated cipher with 96-bit unique cryptographically random nonces and 128-bit authentication tags.
- **Hardware-Protected Master Key:** 256-bit symmetric key stored inside the iOS Keychain using `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- **Zero Plaintext Persisted:** Media payloads, thumbnails, and vault metadata are encrypted before touching flash storage.
- **Data Protection Class Complete:** File attributes tagged with `NSFileProtectionComplete` preventing access while the device is locked.

### 4. Portable Encrypted Backup & Restore
- **Standard PKZip Outer Container:** Standard `.zip` archive format compatible with macOS Archive Utility, Windows Explorer, and iOS Files app.
- **Zero Content Leak in Archive:** Plaintext photos, videos, and filenames are never visible inside the ZIP container.
- **Key Derivation Function:** PBKDF2 with HMAC-SHA256, 100,000 iterations, and a unique 16-byte random salt.
- **Payload Integrity:** Cryptographically verifies payload SHA-256 before decryption.
- **Defensive Extraction:** Full protection against **Zip Slip** (path traversal) and **Decompression Bomb / Zip Bomb** attacks.
- **Transactional Rollback:** Restoration creates an atomic safety snapshot. Any failure automatically rolls back to the prior state—existing data can never be silently corrupted.
- **Restoration Modes:** Choice of **Merge** (appends non-duplicate items and new albums) or **Replace** (complete wipe and replacement).

### 5. Multi-Layer Authentication
- **Biometric Authentication:** Face ID / Touch ID via `LocalAuthentication`.
- **Hardware PIN Fallback:** 4-6 digit numeric PIN salted and hashed with SHA-256 stored in Keychain.
- **Automatic Lockout:** 30-second progressive lockout after 5 consecutive failed attempts.
- **Configurable Auto-Lock:** Immediately, 30s, 1m, 5m, or Never.
- **App Switcher Privacy Shield:** High-blur privacy overlay obscures screen contents when transitioning between apps or taking system snapshots.

---

## 🏗 Project Architecture

PrivateVault Pro strictly adheres to Clean Architecture and SOLID design principles, utilizing dependency injection with protocols for testability:

```
PrivateVaultPro/
├── App/
│   ├── PrivateVaultProApp.swift       # SwiftUI App entry point
│   ├── AppEnvironment.swift           # Dependency injection container
│   └── AppState.swift                 # Central reactive state & session coordinator
├── Core/
│   ├── Crypto/
│   │   ├── CryptoService.swift        # CryptoKit AES-256-GCM implementation
│   │   ├── PBKDF2KeyDerivation.swift  # PBKDF2-HMAC-SHA256 key derivation
│   │   └── EncryptionKeyManager.swift # Master vault key lifecycle & Keychain binding
│   ├── Storage/
│   │   ├── KeychainService.swift      # Secure Keychain wrapper
│   │   └── VaultStorageService.swift  # Atomic encrypted file storage coordinator
│   ├── Authentication/
│   │   ├── AuthenticationService.swift# PIN, lockout, auto-lock rules
│   │   └── BiometricManager.swift     # LocalAuthentication Face ID/Touch ID bridge
│   ├── Backup/
│   │   ├── BackupManifest.swift       # Backup metadata & payload specifications
│   │   ├── BackupZipHandler.swift     # Zero-dependency PKZip encoder/decoder
│   │   ├── ZipSafetyValidator.swift   # Zip Slip & DoS protection validator
│   │   ├── BackupService.swift        # Backup packaging & export pipeline
│   │   └── RestoreService.swift       # Transactional verification & restore
│   └── Media/
│       ├── MediaImportService.swift   # PhotosPicker importer & deduplication
│       ├── MediaExportService.swift   # Decryption to Photos / Share Sheet
│       ├── AlbumService.swift         # Album creation, renaming & media assignment
│       └── ThumbnailService.swift     # CGImageSource thumbnail generator & NSCache
├── Models/
│   ├── MediaItem.swift                # Encrypted media item model
│   ├── Album.swift                    # Album representation
│   ├── VaultMetadata.swift            # Vault database root model
│   ├── ActivityLogEntry.swift         # Sanitized activity log model
│   ├── AppSettings.swift              # Security & UX preferences
│   └── AppTheme.swift                 # System, Dark, and Light themes
├── Views/
│   ├── Main/                          # Root container, Tab view, Privacy blur
│   ├── Dashboard/                     # VPN status ring, metrics, activity log
│   ├── Authentication/                # Lock screen, PIN entry, Setup wizard
│   ├── Gallery/                       # Grid, thumbnails, detail viewer, video player
│   ├── Albums/                        # Album grid, album detail, creation sheet
│   ├── Backup/                        # Backup generator, restore preview sheet
│   ├── Settings/                      # Security, theme, storage, about
│   └── Components/                    # GlassCard, GlowModifier, ShareSheet, Toasts
├── Utilities/                         # Haptics, Date & Byte formatters, Color themes
└── Resources/                         # Info.plist, Entitlements, Assets.xcassets
```

---

## 🔒 Security Specifications

| Layer | Standard | Details |
| :--- | :--- | :--- |
| **Media Cipher** | AES-256-GCM | 256-bit symmetric key, 96-bit random nonce, 128-bit authentication tag |
| **Backup KDF** | PBKDF2-HMAC-SHA256 | 100,000 iterations, 16-byte random salt, 256-bit output key |
| **Key Storage** | iOS Keychain | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| **File Protection** | NSFileProtectionComplete | Files are hardware-encrypted when iPhone screen is locked |
| **Deduplication** | SHA-256 | Prevents importing duplicate media items |
| **Archive Defense** | Zip Slip Protection | Rejects `..`, absolute paths, colon notation, path normalization escaping |
| **Bomb Defense** | Resource Thresholds | Rejects archives > 20 GB or > 50,000 file entries |
| **Network** | Air-Gapped | Zero outgoing network permissions, zero socket calls |

---

## 🚀 Build & Installation

Please refer to [`BUILD_AND_TEST_GUIDE.md`](file:///PrivateVaultPro/BUILD_AND_TEST_GUIDE.md) for full instructions on building via Xcode 15/16, running test suites, and generating signed IPA release builds.

---

## 📄 Documentation Index
- **[System Architecture](file:///ARCHITECTURE.md):** Detailed component diagrams and state lifecycle.
- **[Cryptographic Specification](file:///CRYPTO_SPECIFICATION.md):** Mathematical formulas, key derivation, and threat modeling.
- **[Security Review Audit](file:///SECURITY_REVIEW.md):** In-depth security analysis and risk assessment.
- **[Build & Testing Guide](file:///BUILD_AND_TEST_GUIDE.md):** Step-by-step compilation, test execution, and CI/CD automation.
