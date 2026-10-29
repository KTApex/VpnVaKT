# PrivateVault Pro — Cryptographic Specification

This document provides a formal definition of the cryptographic primitives, key hierarchies, data formats, and security guarantees implemented in **PrivateVault Pro**.

---

## 1. Cryptographic Primitives

| Component | Primitive | Specification |
| :--- | :--- | :--- |
| **Symmetric Cipher** | AES-GCM (Authenticated Encryption) | NIST SP 800-38D, 256-bit key |
| **Nonce Length** | 96 bits (12 bytes) | Cryptographically secure random (`SecRandomCopyBytes` via CryptoKit `AES.GCM.Nonce()`) |
| **Authentication Tag** | 128 bits (16 bytes) | Galois Message Authentication Code (GMAC) |
| **Digest / Deduplication** | SHA-256 | FIPS PUB 180-4 (256 bits) |
| **Password Key Derivation (KDF)** | PBKDF2 with HMAC-SHA256 | RFC 2898 / RFC 8018, 100,000 iterations, 16-byte random salt |
| **Key Storage** | iOS Keychain Services | Hardware-backed Keybag, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |

---

## 2. Key Hierarchy & Lifecycle

### 2.1 Master Vault Key
1. **Generation:** When the vault is first initialized, a 256-bit symmetric key is generated using Apple CryptoKit:
   $$\text{MasterKey} \leftarrow \text{CryptoKit.SymmetricKey}(\text{size: 256 bits})$$
2. **Storage:** The key is immediately persisted in the iOS Keychain under the account identifier `master_vault_aes256_key`. It is assigned the access attribute `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, which guarantees:
   - The key is encrypted by the device hardware keybag while the iPhone is locked.
   - The key is non-migratory (cannot be extracted through iTunes / iCloud unencrypted backups).
   - The key exists solely on this physical device.

### 2.2 Backup Passphrase Key Derivation
To ensure zero-knowledge portable backups, backup encryption keys are derived dynamically from a user-supplied passphrase:
1. **Salt Generation:** A 16-byte random salt $S$ is generated using hardware randomness (`SecRandomCopyBytes`).
2. **Key Derivation Function (KDF):**
   $$\text{BackupKey} = \text{PBKDF2}(\text{PRF}=\text{HMAC-SHA256}, \text{Password}=P, \text{Salt}=S, c=100{,}000, dkLen=32)$$
3. **Passphrase Ephemerality:** Neither the raw backup passphrase $P$ nor the derived $\text{BackupKey}$ is ever written to persistent storage or logged. Once backup encoding or restore decoding completes, the key is unlinked from memory.

---

## 3. Data Formats & Ciphertext Construction

### 3.1 Encrypted File Container Format
Every encrypted file (media file, thumbnail file, and metadata file) uses standard AES-GCM combined representation:

```
+-------------------+-----------------------------------+--------------------+
| Nonce (12 Bytes)  | Ciphertext (N Bytes)              | Tag (16 Bytes)     |
+-------------------+-----------------------------------+--------------------+
```

- **Nonce (12 Bytes):** Random 96-bit value generated fresh for every encryption operation.
- **Ciphertext (N Bytes):** AES-CTR encrypted payload bytes.
- **Tag (16 Bytes):** 128-bit authentication tag calculated over the ciphertext and nonce.

### 3.2 Backup ZIP Layout & Manifest Format
The backup archive is packaged as a standard PKZip containing two files:
1. `manifest.json`: An unencrypted JSON manifest providing parameters required for restoration:
   ```json
   {
     "backupVersion": 1,
     "appVersion": "1.0.0",
     "createdAt": "2026-10-29T10:00:00Z",
     "kdfAlgorithm": "PBKDF2-HMAC-SHA256",
     "kdfIterations": 100000,
     "saltBase64": "G8uH9V...",
     "encryptionAlgorithm": "AES-256-GCM",
     "payloadSHA256": "4b68e983...",
     "totalMediaCount": 245,
     "photoCount": 210,
     "videoCount": 35,
     "albumCount": 6,
     "totalPayloadBytes": 384920184
   }
   ```
2. `vault_payload.enc`: The AES-256-GCM combined ciphertext of the encoded `DecryptedBackupPayload` struct, containing all encrypted media files, thumbnails, and complete vault metadata.

---

## 4. Threat Model & Security Guarantees

### 4.1 In Scope & Protected
- **Offline Device Theft / Physical Extraction:** While the iPhone is locked, data is protected by `NSFileProtectionComplete` and Keychain hardware access controls. An attacker performing a NAND flash dump cannot read photos or metadata without the device passcode / Secure Enclave unlock.
- **Ciphertext Tampering / Bit-Flipping:** AES-GCM tags guarantee that any modification of encrypted files in storage causes decryption to fail immediately with `.authenticationFailed`.
- **Man-in-the-Middle / Cloud Interception:** The app is completely air-gapped with zero network calls; backups transferred via AirDrop or USB remain encrypted with AES-256.
- **Decompression Abuse (Zip Slip & Zip Bombs):** Paths are validated against directory traversal (`..`, absolute paths), and decompression size limits are enforced before extraction.

### 4.2 Known Cryptographic Limitations & Mitigations
- **Metadata File Size / Traffic Analysis:** While file contents and original names are fully encrypted, file sizes can be observed by inspecting storage.
  *Mitigation:* The total item count and approximate storage footprint are visible, but media contents remain completely opaque.
- **Weak Backup Passwords:** If a user chooses an overly simple backup password (e.g., `123456`), dictionary attacks could be attempted offline.
  *Mitigation:* The KDF enforces 100,000 iterations of PBKDF2-HMAC-SHA256, significantly raising the computational cost of brute-force attempts on GPU clusters.
