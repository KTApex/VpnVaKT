# PrivateVault Pro — Architectural Specification

This document details the software architecture, design patterns, data flows, and state management implemented in **PrivateVault Pro**.

---

## 1. High-Level System Architecture

The application is architected around the **Dependency Injection** pattern, decoupling the presentation layer from the persistence, cryptographic, and media services.

```mermaid
graph TD
    UI[SwiftUI Views & Navigation] --> AppState[AppState Coordinator]
    AppState --> AppEnvironment[AppEnvironment Container]
    
    subgraph Services Layer
        AppEnvironment --> Auth[AuthenticationService]
        AppEnvironment --> Storage[VaultStorageService]
        AppEnvironment --> Import[MediaImportService]
        AppEnvironment --> Export[MediaExportService]
        AppEnvironment --> Album[AlbumService]
        AppEnvironment --> Thumb[ThumbnailService]
        AppEnvironment --> Backup[BackupService]
        AppEnvironment --> Restore[RestoreService]
    end

    subgraph Security Layer
        Auth --> Bio[BiometricManager LocalAuthentication]
        Auth --> KeyMgr[EncryptionKeyManager]
        Storage --> KeyMgr
        Storage --> Crypto[CryptoService CryptoKit]
        Storage --> Keychain[KeychainService Security.framework]
        Backup --> Crypto
        Backup --> PBKDF[PBKDF2KeyDerivation CommonCrypto]
        Restore --> Crypto
        Restore --> PBKDF
        Restore --> ZipVal[ZipSafetyValidator]
    end

    subgraph Hardware & Disk
        Keychain --> SecureEnclave[iOS Keychain Hardware Storage]
        Storage --> FileSystem[ApplicationSupport/SecureVault completeFileProtection]
        Bio --> Sensor[Face ID / Touch ID Hardware Sensor]
    end
```

---

## 2. Authentication & Session Flow

The app enforces a fail-safe security boundary across all scene transitions:

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant App as AppState
    participant Auth as AuthenticationService
    participant Bio as BiometricManager
    participant Keychain as KeychainService

    User->>App: Launch App
    App->>Auth: Check if PIN configured
    alt No PIN Configured
        Auth-->>App: false
        App->>User: Present SetupPinView
        User->>Auth: Submit & Confirm 4-digit PIN
        Auth->>Keychain: Store Salt + SHA256(PIN + Salt)
        Auth-->>App: PIN Configured & Vault Unlocked
    else PIN Exists
        Auth-->>App: true
        App->>User: Present LockScreenView
        alt Biometrics Enabled
            App->>Bio: authenticate(reason)
            Bio->>User: Face ID / Touch ID Prompt
            alt Success
                Bio-->>App: Verified
                App->>Auth: unlock()
                App->>User: Transition to MainTabView
            else Biometrics Cancelled / Failed
                User->>App: Enter PIN on Keypad
                App->>Auth: authenticateWithPIN(pin)
                Auth->>Keychain: Compare SHA256(pin + salt)
                Auth-->>App: Success
                App->>User: Transition to MainTabView
            end
        end
    end
```

---

## 3. Media Import Pipeline

When the user selects photos or videos via `PhotosPicker`, the import pipeline executes sequentially with atomic disk commits:

```mermaid
flowchart TD
    A[PhotosPicker Selection] --> B[Read Transferable Binary Data]
    B --> C[Compute SHA-256 Digest]
    C --> D{Hash Exists in Vault?}
    D -- Yes --> E[Skip Duplicate & Log]
    D -- No --> F[Generate Downscaled Thumbnail]
    F --> G[Obtain Master Key from Keychain]
    G --> H[CryptoKit AES-256-GCM Seal Media & Thumbnail]
    H --> I[Write Encrypted Files to SecureVault Directory]
    I --> J[Verify File Existence on Disk]
    J --> K[Insert MediaItem into VaultMetadata]
    K --> L[Encrypt and Save metadata.enc]
    L --> M{Ask to Delete Originals?}
    M -- Yes --> N[Request PHPhotoLibrary Authorization]
    N --> O[Execute PHAssetChangeRequest.deleteAssets]
    O --> P[Report Actual Deletion Result to User]
    M -- No --> Q[Completed]
    P --> Q
```

---

## 4. Encrypted Backup & Transactional Restore

### Backup Structure
A portable backup is formatted as an uncompressed, standard PKZip archive containing exactly two files:

```
PrivateVault_Backup_2026-10-29.zip
├── manifest.json       (Unencrypted plaintext manifest with KDF params, salt, SHA-256 hash)
└── vault_payload.enc   (AES-256-GCM encrypted payload containing metadata, media, thumbnails)
```

### Transactional Restore Sequence

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Restore as RestoreService
    participant ZipHandler as BackupZipHandler
    participant Validator as ZipSafetyValidator
    participant Storage as VaultStorageService

    User->>Restore: Select Backup ZIP
    Restore->>ZipHandler: Parse Central Directory
    ZipHandler->>Validator: Validate Entry Names (Zip Slip)
    ZipHandler->>Validator: Validate Total Sizes & Entry Limits
    Restore->>User: Prompt for Backup Password
    User->>Restore: Submit Password
    Restore->>Restore: PBKDF2(Password, Manifest Salt, 100k rounds)
    Restore->>Restore: AES-GCM Open(vault_payload.enc)
    Restore->>Restore: Verify Payload SHA-256 == Manifest Hash
    Restore->>User: Display Preview (New items, Duplicates)
    User->>Restore: Select Merge or Replace
    Note over Restore,Storage: Step 1: Create Rollback Snapshot of Vault
    Restore->>Storage: Snapshot current vault to tmp directory
    Note over Restore,Storage: Step 2: Apply Changes
    alt Successful Write
        Restore->>Storage: Commit new files and metadata
        Restore->>Storage: Purge Rollback Snapshot
        Restore-->>User: Success
    else Error Encountered
        Restore->>Storage: Revert vault from Rollback Snapshot
        Restore-->>User: Report Failure (Zero Data Lost)
    end
```

---

## 5. Memory Management & Performance

- **Lazy UI Rendering:** SwiftUI `LazyVGrid` and `LazyVStack` guarantee that thumbnails are only inflated when visible within the viewport.
- **Two-Tier Thumbnail Cache:**
  - `NSCache` with a 100MB cost limit and 500-item eviction policy keeps active viewport thumbnails in memory without causing memory pressure or termination.
  - On-disk thumbnails (`.thumb.enc`) are downscaled to 320px maximum dimension, consuming ~30KB per photo rather than multi-megabyte raw files.
- **Video Decryption Streaming:** Videos are never buffered entirely in RAM. They are streamed via temporary file handles created with `NSFileProtectionComplete` inside `NSTemporaryDirectory()` and immediately purged upon playback view dismissal.
