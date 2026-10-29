# PrivateVault Pro — Build, Test & Distribution Guide

This guide provides instructions for compiling, testing, and distributing **PrivateVault Pro** using Xcode 15 / 16 on macOS.

---

## 1. Environment & Prerequisites

- **macOS:** macOS Sonoma 14.0+ or macOS Sequoia 15.0+
- **Xcode:** Xcode 15.0+ or Xcode 16.0+
- **Swift:** Swift 5.9 or Swift 6.0
- **Target OS:** iOS 17.0+ (iPhone & iPad)
- **Dependencies:** **Zero external CocoaPods, Carthage, or Swift Package Manager dependencies.** The app uses 100% native Apple frameworks (`SwiftUI`, `CryptoKit`, `LocalAuthentication`, `PhotosUI`, `AVKit`, `CommonCrypto`).

> **Note on Windows Environments:**  
> iOS applications require the Apple Darwin toolchain, Clang, and the iOS SDK which are exclusively available on macOS. If you are developing on a Windows host, commit this repository to Git and run the build and test suites on a macOS machine, a local Mac mini, or a cloud macOS CI runner (e.g., GitHub Actions `macos-14`).

---

## 2. Project Structure Verification

Confirm the directory structure before opening in Xcode:

```
PrivateVaultPro/
├── PrivateVaultPro.xcodeproj/
│   └── project.pbxproj
├── PrivateVaultPro/
│   ├── App/
│   ├── Core/
│   │   ├── Crypto/
│   │   ├── Storage/
│   │   ├── Authentication/
│   │   ├── Backup/
│   │   └── Media/
│   ├── Models/
│   ├── ViewModels/
│   ├── Views/
│   ├── Utilities/
│   └── Resources/
│       ├── Info.plist
│       ├── PrivateVaultPro.entitlements
│       └── Assets.xcassets/
├── PrivateVaultProTests/
└── PrivateVaultProUITests/
```

---

## 3. Opening in Xcode & Building

1. Launch Xcode on macOS.
2. Select **File → Open...** and open `PrivateVaultPro.xcodeproj`.
3. In the scheme selector at the top toolbar, select `PrivateVaultPro` and choose an iOS 17+ Simulator target (e.g., **iPhone 15 Pro** or **iPhone 16**).
4. Press **⌘B** (Product → Build) to compile the application.
5. Press **⌘R** (Product → Run) to launch the app on the simulator.

---

## 4. Running the Test Suites

### 4.1 From Xcode GUI
1. Press **⌘U** (Product → Test).
2. The Test Navigator (⌘6) will display all passing unit and UI test cases.

### 4.2 From Command Line (CLI / CI)
Run the following terminal command on macOS to execute the complete test suite:

```bash
xcodebuild test \
  -project PrivateVaultPro/PrivateVaultPro.xcodeproj \
  -scheme PrivateVaultProTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0' \
  -resultBundlePath TestResults.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

### 4.3 Expected Test Matrix & Results
All tests in the test suite validate core security and operational contracts:

| Test Class | Scope | Expected Result |
| :--- | :--- | :--- |
| `CryptoServiceTests` | AES-256-GCM seal/open, tamper detection, SHA-256 | **PASS (100%)** |
| `PBKDF2Tests` | 100k rounds deterministic key derivation, salt length | **PASS (100%)** |
| `VaultStorageTests` | Encrypted read/write, thumbnail persistence, metadata | **PASS (100%)** |
| `ZipSafetyTests` | Zip Slip path traversal rejection, DoS thresholds | **PASS (100%)** |
| `BackupAndRestoreTests` | End-to-end ZIP packaging, Merge & Replace restoration | **PASS (100%)** |
| `CorruptedBackupTests` | Wrong password rejection, tampered hash detection | **PASS (100%)** |
| `AlbumServiceTests` | Album creation, rename, safe deletion without media loss | **PASS (100%)** |
| `AuthenticationServiceTests` | PIN hashing, 5-failure lockout, auto-lock timeouts | **PASS (100%)** |
| `MediaImportTests` | Import pipeline, SHA-256 duplicate rejection | **PASS (100%)** |
| `PrivateVaultProUITests` | Launch flow, Setup/Lock view, tab bar navigation | **PASS (100%)** |

---

## 5. Exporting a Signed IPA for Distribution

To distribute to testers (TestFlight, Ad-Hoc, or Enterprise):

### Step 1: Create Archive
```bash
xcodebuild archive \
  -project PrivateVaultPro/PrivateVaultPro.xcodeproj \
  -scheme PrivateVaultPro \
  -configuration Release \
  -archivePath ./build/PrivateVaultPro.xcarchive
```

### Step 2: Create `ExportOptions.plist`
Create a configuration file `ExportOptions.plist` specifying your distribution method (e.g., `app-store`, `ad-hoc`, or `development`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
```

### Step 3: Export IPA
```bash
xcodebuild -exportArchive \
  -archivePath ./build/PrivateVaultPro.xcarchive \
  -exportPath ./build/ExportedApp \
  -exportOptionsPlist ExportOptions.plist
```

The resulting signed `PrivateVaultPro.ipa` will be generated inside `./build/ExportedApp/`.

---

## 6. Continuous Integration (GitHub Actions)

Add this workflow file at `.github/workflows/ios.yml` for automated CI building and testing on every pull request:

```yaml
name: iOS CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-and-test:
    runs-on: macos-14
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Select Xcode version
        run: sudo xcode-select -s /Applications/Xcode_15.4.app

      - name: Run Unit Tests
        run: |
          xcodebuild test \
            -project PrivateVaultPro/PrivateVaultPro.xcodeproj \
            -scheme PrivateVaultProTests \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0' \
            CODE_SIGNING_ALLOWED=NO
```
