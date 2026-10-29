//
//  BackupZipHandler.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation

public struct ZipEntry {
    public let filename: String
    public let data: Data

    public init(filename: String, data: Data) {
        self.filename = filename
        self.data = data
    }
}

public final class BackupZipHandler {

    // MARK: - CRC32 Lookup Table & Calculation

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                if (c & 1) != 0 {
                    c = 0xEDB88320 ^ (c >> 1)
                } else {
                    c = c >> 1
                }
            }
            return c
        }
    }()

    public static func crc32(data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        data.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for i in 0..<data.count {
                let index = Int((crc ^ UInt32(ptr[i])) & 0xFF)
                crc = crcTable[index] ^ (crc >> 8)
            }
        }
        return crc ^ 0xFFFFFFFF
    }

    // MARK: - Archive Creation

    /// Creates a standard PKZip archive containing the provided entries.
    public static func createArchive(entries: [ZipEntry]) throws -> Data {
        var archiveData = Data()
        var centralDirectoryData = Data()
        var localHeaderOffsets: [UInt32] = []

        for entry in entries {
            try ZipSafetyValidator.validateEntryPath(entry.filename)
            let currentOffset = UInt32(archiveData.count)
            localHeaderOffsets.append(currentOffset)

            let filenameBytes = Data(entry.filename.utf8)
            let crc = crc32(data: entry.data)
            let size = UInt32(entry.data.count)

            // Local File Header (30 bytes + filename)
            var localHeader = Data()
            localHeader.appendUInt32(0x04034B50) // Local header signature
            localHeader.appendUInt16(20)         // Version needed (2.0)
            localHeader.appendUInt16(0x0800)     // General purpose bit flag (UTF-8)
            localHeader.appendUInt16(0)          // Compression method: Store (0)
            localHeader.appendUInt16(0)          // Last mod time
            localHeader.appendUInt16(0x5460)     // Last mod date
            localHeader.appendUInt32(crc)        // CRC-32
            localHeader.appendUInt32(size)       // Compressed size
            localHeader.appendUInt32(size)       // Uncompressed size
            localHeader.appendUInt16(UInt16(filenameBytes.count)) // Filename length
            localHeader.appendUInt16(0)          // Extra field length
            localHeader.append(filenameBytes)    // Filename

            archiveData.append(localHeader)
            archiveData.append(entry.data)

            // Central Directory Entry (46 bytes + filename)
            var cdEntry = Data()
            cdEntry.appendUInt32(0x02014B50)     // Central directory signature
            cdEntry.appendUInt16(20)             // Version made by
            cdEntry.appendUInt16(20)             // Version needed
            cdEntry.appendUInt16(0x0800)         // Bit flag (UTF-8)
            cdEntry.appendUInt16(0)              // Compression: Store (0)
            cdEntry.appendUInt16(0)              // Mod time
            cdEntry.appendUInt16(0x5460)         // Mod date
            cdEntry.appendUInt32(crc)            // CRC-32
            cdEntry.appendUInt32(size)           // Compressed size
            cdEntry.appendUInt32(size)           // Uncompressed size
            cdEntry.appendUInt16(UInt16(filenameBytes.count)) // Filename length
            cdEntry.appendUInt16(0)              // Extra field length
            cdEntry.appendUInt16(0)              // Comment length
            cdEntry.appendUInt16(0)              // Disk number start
            cdEntry.appendUInt16(0)              // Internal attributes
            cdEntry.appendUInt32(0)              // External attributes
            cdEntry.appendUInt32(currentOffset)  // Relative offset of local header
            cdEntry.append(filenameBytes)        // Filename

            centralDirectoryData.append(cdEntry)
        }

        let cdOffset = UInt32(archiveData.count)
        let cdSize = UInt32(centralDirectoryData.count)
        let totalEntries = UInt16(entries.count)

        archiveData.append(centralDirectoryData)

        // End of Central Directory Record (22 bytes)
        var eocd = Data()
        eocd.appendUInt32(0x06054B50)            // EOCD signature
        eocd.appendUInt16(0)                     // Number of this disk
        eocd.appendUInt16(0)                     // Disk with start of CD
        eocd.appendUInt16(totalEntries)          // Total entries on this disk
        eocd.appendUInt16(totalEntries)          // Total entries
        eocd.appendUInt32(cdSize)                // CD size
        eocd.appendUInt32(cdOffset)              // CD offset
        eocd.appendUInt16(0)                     // Comment length

        archiveData.append(eocd)
        return archiveData
    }

    // MARK: - Archive Extraction

    /// Extracts entries from a valid ZIP archive data buffer with safety validation.
    public static func extractArchive(data: Data) throws -> [ZipEntry] {
        guard data.count >= 22 else {
            throw ZipSafetyError.malformedArchive("File size is smaller than minimum ZIP header.")
        }

        // Find End of Central Directory Record from the end
        var eocdOffset: Int?
        let maxSearchLength = min(data.count, 65535 + 22)
        let searchStart = data.count - maxSearchLength

        for i in stride(from: data.count - 22, through: searchStart, by: -1) {
            let sig = data.readUInt32(at: i)
            if sig == 0x06054B50 {
                eocdOffset = i
                break
            }
        }

        guard let eocdPos = eocdOffset else {
            throw ZipSafetyError.invalidHeaderSignature
        }

        let totalEntries = Int(data.readUInt16(at: eocdPos + 10))
        let cdSize = Int(data.readUInt32(at: eocdPos + 12))
        let cdOffset = Int(data.readUInt32(at: eocdPos + 16))

        try ZipSafetyValidator.validateLimits(entryCount: totalEntries, totalBytes: Int64(data.count))

        guard cdOffset + cdSize <= data.count else {
            throw ZipSafetyError.malformedArchive("Central directory bounds exceed archive size.")
        }

        var results: [ZipEntry] = []
        var currentCDPos = cdOffset

        for _ in 0..<totalEntries {
            guard currentCDPos + 46 <= data.count else {
                throw ZipSafetyError.malformedArchive("Truncated central directory entry.")
            }

            let sig = data.readUInt32(at: currentCDPos)
            guard sig == 0x02014B50 else {
                throw ZipSafetyError.malformedArchive("Invalid central directory signature at offset \(currentCDPos).")
            }

            let compressionMethod = data.readUInt16(at: currentCDPos + 10)
            let uncompressedSize = Int(data.readUInt32(at: currentCDPos + 24))
            let filenameLength = Int(data.readUInt16(at: currentCDPos + 28))
            let extraLength = Int(data.readUInt16(at: currentCDPos + 30))
            let commentLength = Int(data.readUInt16(at: currentCDPos + 32))
            let localHeaderOffset = Int(data.readUInt32(at: currentCDPos + 42))

            let nameStart = currentCDPos + 46
            guard nameStart + filenameLength <= data.count else {
                throw ZipSafetyError.malformedArchive("Central directory filename out of bounds.")
            }

            let nameData = data.subdata(in: nameStart..<(nameStart + filenameLength))
            let filename = String(decoding: nameData, as: UTF8.self)

            try ZipSafetyValidator.validateEntryPath(filename)

            // Read from local file header
            guard localHeaderOffset + 30 <= data.count else {
                throw ZipSafetyError.malformedArchive("Local header offset out of bounds for \(filename).")
            }

            let localSig = data.readUInt32(at: localHeaderOffset)
            guard localSig == 0x04034B50 else {
                throw ZipSafetyError.malformedArchive("Invalid local header signature for \(filename).")
            }

            let localNameLength = Int(data.readUInt16(at: localHeaderOffset + 26))
            let localExtraLength = Int(data.readUInt16(at: localHeaderOffset + 28))
            let dataStart = localHeaderOffset + 30 + localNameLength + localExtraLength

            guard dataStart + uncompressedSize <= data.count else {
                throw ZipSafetyError.malformedArchive("Entry data out of bounds for \(filename).")
            }

            let entryData: Data
            if compressionMethod == 0 {
                // Store (uncompressed)
                entryData = data.subdata(in: dataStart..<(dataStart + uncompressedSize))
            } else {
                // In our container, files are stored uncompressed (encryption already scrambles entropy)
                // If standard deflate is encountered, read slice
                entryData = data.subdata(in: dataStart..<(dataStart + uncompressedSize))
            }

            results.append(ZipEntry(filename: filename, data: entryData))
            currentCDPos += 46 + filenameLength + extraLength + commentLength
        }

        return results
    }
}

// MARK: - Data Byte Helpers

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var v = value.littleEndian
        withUnsafeBytes(of: &v) { self.append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var v = value.littleEndian
        withUnsafeBytes(of: &v) { self.append(contentsOf: $0) }
    }

    func readUInt16(at offset: Int) -> UInt16 {
        let sub = self.subdata(in: offset..<(offset + 2))
        return sub.withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
    }

    func readUInt32(at offset: Int) -> UInt32 {
        let sub = self.subdata(in: offset..<(offset + 4))
        return sub.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
    }
}
