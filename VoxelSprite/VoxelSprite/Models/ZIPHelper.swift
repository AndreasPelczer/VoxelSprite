//
//  ZIPHelper.swift
//  VoxelSprite
//
//  Erstellt ZIP-Archive aus Verzeichnissen.
//  Nutzt Foundation-APIs für die Komprimierung.
//

import Foundation

struct ZIPHelper {

    /// Erstellt ein ZIP-Archiv aus einem Verzeichnis.
    /// Gibt die URL der erstellten ZIP-Datei zurück.
    static func zipDirectory(at sourceDir: URL, to destinationURL: URL) throws -> URL {
        let fm = FileManager.default

        // Alle Dateien im Verzeichnis rekursiv auflisten
        guard let enumerator = fm.enumerator(at: sourceDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]) else {
            throw ZIPError.cannotEnumerateDirectory
        }

        var entries: [(relativePath: String, data: Data)] = []

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else { continue }

            let relativePath = fileURL.path.replacingOccurrences(
                of: sourceDir.path + "/", with: "")
            let data = try Data(contentsOf: fileURL)
            entries.append((relativePath: relativePath, data: data))
        }

        // ZIP-Datei erstellen
        let zipData = try createZIPData(entries: entries)

        // Ziel-Verzeichnis sicherstellen
        let parentDir = destinationURL.deletingLastPathComponent()
        try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)

        try zipData.write(to: destinationURL, options: .atomic)

        return destinationURL
    }

    /// Erstellt ZIP-Daten aus einer Liste von Einträgen (Store-only, keine Kompression).
    /// Minecraft-Resourcepacks sind klein genug, dass Store-only kein Problem ist.
    private static func createZIPData(entries: [(relativePath: String, data: Data)]) throws -> Data {
        var zipData = Data()
        var centralDirectory = Data()
        var offsets: [Int] = []

        for entry in entries {
            let pathData = Data(entry.relativePath.utf8)
            let fileData = entry.data
            let crc = crc32(fileData)

            offsets.append(zipData.count)

            // Local File Header
            zipData.append(contentsOf: localFileHeader(
                crc: crc,
                size: UInt32(fileData.count),
                nameLength: UInt16(pathData.count)
            ))
            zipData.append(pathData)
            zipData.append(fileData)

            // Central Directory Entry
            centralDirectory.append(contentsOf: centralDirectoryEntry(
                crc: crc,
                size: UInt32(fileData.count),
                nameLength: UInt16(pathData.count),
                offset: UInt32(offsets.last!)
            ))
            centralDirectory.append(pathData)
        }

        // Central Directory Offset
        let centralDirOffset = UInt32(zipData.count)
        zipData.append(centralDirectory)

        // End of Central Directory
        zipData.append(contentsOf: endOfCentralDirectory(
            entryCount: UInt16(entries.count),
            centralDirSize: UInt32(centralDirectory.count),
            centralDirOffset: centralDirOffset
        ))

        return zipData
    }

    // MARK: - ZIP Structure Helpers

    private static func localFileHeader(crc: UInt32, size: UInt32, nameLength: UInt16) -> [UInt8] {
        var header: [UInt8] = []
        header.append(contentsOf: uint32Bytes(0x04034b50))  // signature
        header.append(contentsOf: uint16Bytes(20))           // version needed (2.0)
        header.append(contentsOf: uint16Bytes(0))            // flags
        header.append(contentsOf: uint16Bytes(0))            // compression (store)
        header.append(contentsOf: uint16Bytes(0))            // mod time
        header.append(contentsOf: uint16Bytes(0))            // mod date
        header.append(contentsOf: uint32Bytes(crc))          // crc-32
        header.append(contentsOf: uint32Bytes(size))         // compressed size
        header.append(contentsOf: uint32Bytes(size))         // uncompressed size
        header.append(contentsOf: uint16Bytes(nameLength))   // filename length
        header.append(contentsOf: uint16Bytes(0))            // extra field length
        return header
    }

    private static func centralDirectoryEntry(crc: UInt32, size: UInt32, nameLength: UInt16, offset: UInt32) -> [UInt8] {
        var entry: [UInt8] = []
        entry.append(contentsOf: uint32Bytes(0x02014b50))  // signature
        entry.append(contentsOf: uint16Bytes(20))           // version made by
        entry.append(contentsOf: uint16Bytes(20))           // version needed
        entry.append(contentsOf: uint16Bytes(0))            // flags
        entry.append(contentsOf: uint16Bytes(0))            // compression (store)
        entry.append(contentsOf: uint16Bytes(0))            // mod time
        entry.append(contentsOf: uint16Bytes(0))            // mod date
        entry.append(contentsOf: uint32Bytes(crc))          // crc-32
        entry.append(contentsOf: uint32Bytes(size))         // compressed size
        entry.append(contentsOf: uint32Bytes(size))         // uncompressed size
        entry.append(contentsOf: uint16Bytes(nameLength))   // filename length
        entry.append(contentsOf: uint16Bytes(0))            // extra field length
        entry.append(contentsOf: uint16Bytes(0))            // comment length
        entry.append(contentsOf: uint16Bytes(0))            // disk number
        entry.append(contentsOf: uint16Bytes(0))            // internal attributes
        entry.append(contentsOf: uint32Bytes(0))            // external attributes
        entry.append(contentsOf: uint32Bytes(offset))       // local header offset
        return entry
    }

    private static func endOfCentralDirectory(entryCount: UInt16, centralDirSize: UInt32, centralDirOffset: UInt32) -> [UInt8] {
        var eocdr: [UInt8] = []
        eocdr.append(contentsOf: uint32Bytes(0x06054b50))  // signature
        eocdr.append(contentsOf: uint16Bytes(0))            // disk number
        eocdr.append(contentsOf: uint16Bytes(0))            // disk with CD
        eocdr.append(contentsOf: uint16Bytes(entryCount))   // entries on this disk
        eocdr.append(contentsOf: uint16Bytes(entryCount))   // total entries
        eocdr.append(contentsOf: uint32Bytes(centralDirSize))    // CD size
        eocdr.append(contentsOf: uint32Bytes(centralDirOffset))  // CD offset
        eocdr.append(contentsOf: uint16Bytes(0))            // comment length
        return eocdr
    }

    // MARK: - Byte Helpers

    private static func uint16Bytes(_ value: UInt16) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]
    }

    private static func uint32Bytes(_ value: UInt32) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
         UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)]
    }

    // MARK: - CRC-32

    private static let crcTable: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = 0xEDB88320 ^ (crc >> 1)
                } else {
                    crc = crc >> 1
                }
            }
            table[i] = crc
        }
        return table
    }()

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = crcTable[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}

// MARK: - Fehlertypen

enum ZIPError: LocalizedError {
    case cannotEnumerateDirectory
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .cannotEnumerateDirectory: return "Verzeichnis konnte nicht gelesen werden"
        case .compressionFailed:        return "ZIP-Komprimierung fehlgeschlagen"
        }
    }
}
