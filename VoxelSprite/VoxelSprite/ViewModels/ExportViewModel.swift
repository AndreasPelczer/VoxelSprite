//
//  ExportViewModel.swift
//  VoxelSprite
//
//  Zuständig für Minecraft Resourcepack Export:
//  - Einzelne Face-PNGs (16×16)
//  - block.json / blockstate.json
//  - Komplettes Resourcepack-ZIP
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

class ExportViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isExporting: Bool = false
    @Published var showShareSheet: Bool = false
    @Published var exportedFileURL: URL?
    @Published var additionalExportURLs: [URL] = []
    @Published var errorMessage: String?
    @Published var exportProgress: Double = 0
    @Published var exportStatus: String = ""
    @Published var transparentBackground: Bool = true

    // MARK: - Referenz

    private weak var blockViewModel: BlockViewModel?

    // MARK: - Init

    init() {}

    func connect(to blockViewModel: BlockViewModel) {
        self.blockViewModel = blockViewModel
    }

    // MARK: - Unique Filename

    private func uniqueFileName(base: String, ext: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let shortID = UUID().uuidString.prefix(4)
        return "\(base)_\(timestamp)_\(shortID).\(ext)"
    }

    // MARK: - Einzelne Face-PNGs exportieren

    /// Exportiert alle 6 Faces als einzelne 16×16 PNGs
    func exportFacePNGs() {
        guard let blockVM = blockViewModel else { return }

        isExporting = true
        errorMessage = nil
        exportProgress = 0
        exportStatus = "Faces werden exportiert…"

        let snapshot = blockVM.project

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let urls = try self.createFacePNGs(project: snapshot)

                DispatchQueue.main.async {
                    self.exportProgress = 1.0
                    self.exportStatus = "Fertig!"
                    self.exportedFileURL = urls.first
                    self.additionalExportURLs = Array(urls.dropFirst())
                    self.showShareSheet = true
                    self.isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Export fehlgeschlagen: \(error.localizedDescription)"
                    self.isExporting = false
                    self.exportProgress = 0
                    self.exportStatus = ""
                }
            }
        }
    }

    private func createFacePNGs(project: BlockProject) throws -> [URL] {
        var urls: [URL] = []
        let faces = FaceType.allCases

        for (index, faceType) in faces.enumerated() {
            let canvas = project.canvas(for: faceType)
            guard let cgImage = renderCanvasToCGImage(canvas, gridSize: project.gridSize) else {
                throw ExportError.frameRenderFailed
            }
            guard let pngData = cgImageToPNGData(cgImage) else {
                throw ExportError.pngEncodingFailed
            }

            let fileName = "\(project.name)_\(faceType.rawValue.lowercased()).png"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try pngData.write(to: url, options: .atomic)
            urls.append(url)

            let progress = Double(index + 1) / Double(faces.count)
            DispatchQueue.main.async { [weak self] in
                self?.exportProgress = progress * 0.9
                self?.exportStatus = "\(faceType.rawValue)…"
            }
        }

        return urls
    }

    // MARK: - Minecraft Resourcepack Export

    /// Exportiert ein komplettes Minecraft Resourcepack
    func exportResourcepack() {
        guard let blockVM = blockViewModel else { return }

        isExporting = true
        errorMessage = nil
        exportProgress = 0
        exportStatus = "Resourcepack wird erstellt…"

        let snapshot = blockVM.project

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let url = try self.createResourcepack(project: snapshot)

                DispatchQueue.main.async {
                    self.exportProgress = 1.0
                    self.exportStatus = "Fertig!"
                    self.exportedFileURL = url
                    self.showShareSheet = true
                    self.isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Resourcepack-Export fehlgeschlagen: \(error.localizedDescription)"
                    self.isExporting = false
                    self.exportProgress = 0
                    self.exportStatus = ""
                }
            }
        }
    }

    private func createResourcepack(project: BlockProject) throws -> URL {
        let fm = FileManager.default
        let baseName = uniqueFileName(base: project.name, ext: "")
        let packDir = fm.temporaryDirectory.appendingPathComponent("resourcepack_\(baseName)")

        // Ordnerstruktur erstellen
        let texturesDir = packDir
            .appendingPathComponent("assets/\(project.namespace)/textures/block")
        let modelsDir = packDir
            .appendingPathComponent("assets/\(project.namespace)/models/block")
        let blockstatesDir = packDir
            .appendingPathComponent("assets/\(project.namespace)/blockstates")

        try fm.createDirectory(at: texturesDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: blockstatesDir, withIntermediateDirectories: true)

        DispatchQueue.main.async { [weak self] in
            self?.exportProgress = 0.1
            self?.exportStatus = "Texturen…"
        }

        // 1. Texturen exportieren
        let textureNames = try exportTextures(project: project, to: texturesDir)

        DispatchQueue.main.async { [weak self] in
            self?.exportProgress = 0.5
            self?.exportStatus = "Block Model…"
        }

        // 2. Block Model JSON
        let modelJSON = createBlockModel(project: project, textureNames: textureNames)
        let modelData = try JSONSerialization.data(withJSONObject: modelJSON, options: .prettyPrinted)
        try modelData.write(to: modelsDir.appendingPathComponent("\(project.name).json"), options: .atomic)

        DispatchQueue.main.async { [weak self] in
            self?.exportProgress = 0.7
            self?.exportStatus = "Blockstate…"
        }

        // 3. Blockstate JSON
        let blockstateJSON = createBlockstate(project: project)
        let blockstateData = try JSONSerialization.data(withJSONObject: blockstateJSON, options: .prettyPrinted)
        try blockstateData.write(to: blockstatesDir.appendingPathComponent("\(project.name).json"), options: .atomic)

        DispatchQueue.main.async { [weak self] in
            self?.exportProgress = 0.85
            self?.exportStatus = "pack.mcmeta…"
        }

        // 4. pack.mcmeta
        let packMeta = createPackMeta(project: project)
        let packMetaData = try JSONSerialization.data(withJSONObject: packMeta, options: .prettyPrinted)
        try packMetaData.write(to: packDir.appendingPathComponent("pack.mcmeta"), options: .atomic)

        return packDir
    }

    /// Exportiert die Face-Texturen und gibt die Textur-Pfade zurück
    private func exportTextures(project: BlockProject, to directory: URL) throws -> [FaceType: String] {
        var textureNames: [FaceType: String] = [:]

        // Prüfen welche Faces identische Texturen haben (Template-Optimierung)
        let uniqueTextures = findUniqueTextures(project: project)

        for (faceType, textureName) in uniqueTextures {
            let canvas = project.canvas(for: faceType)
            guard let cgImage = renderCanvasToCGImage(canvas, gridSize: project.gridSize) else {
                throw ExportError.frameRenderFailed
            }
            guard let pngData = cgImageToPNGData(cgImage) else {
                throw ExportError.pngEncodingFailed
            }

            let fileName = "\(textureName).png"
            try pngData.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        }

        // Textur-Zuordnung für alle Faces
        for faceType in FaceType.allCases {
            textureNames[faceType] = findTextureName(for: faceType, in: uniqueTextures)
        }

        return textureNames
    }

    /// Findet einzigartige Texturen basierend auf dem Template
    private func findUniqueTextures(project: BlockProject) -> [(FaceType, String)] {
        switch project.template {
        case .fullBlock:
            return [(.north, project.name)]

        case .grassStyle:
            return [
                (.top, "\(project.name)_top"),
                (.bottom, "\(project.name)_bottom"),
                (.north, "\(project.name)_side")
            ]

        case .pillar:
            return [
                (.top, "\(project.name)_top"),
                (.north, "\(project.name)_side")
            ]

        case .slab, .custom:
            return FaceType.allCases.map { ($0, "\(project.name)_\($0.rawValue.lowercased())") }
        }
    }

    private func findTextureName(for faceType: FaceType, in uniqueTextures: [(FaceType, String)]) -> String {
        // Direkte Zuordnung
        if let direct = uniqueTextures.first(where: { $0.0 == faceType }) {
            return direct.1
        }
        // Fallback: Suche nach Gruppen
        let sides: [FaceType] = [.north, .south, .east, .west]
        if sides.contains(faceType), let sideTexture = uniqueTextures.first(where: { sides.contains($0.0) }) {
            return sideTexture.1
        }
        // Letzter Fallback: erste Textur
        return uniqueTextures.first?.1 ?? "unknown"
    }

    // MARK: - Minecraft JSON Generatoren

    private func createBlockModel(project: BlockProject, textureNames: [FaceType: String]) -> [String: Any] {
        let ns = project.namespace

        var textures: [String: String] = [:]

        // Minecraft Block Model Textur-Referenzen
        if let allName = textureNames[.north], project.template == .fullBlock {
            textures["all"] = "\(ns):block/\(allName)"
        } else {
            for (faceType, name) in textureNames {
                let key: String
                switch faceType {
                case .top:    key = "top"
                case .bottom: key = "bottom"
                case .north:  key = "north"
                case .south:  key = "south"
                case .east:   key = "east"
                case .west:   key = "west"
                }
                textures[key] = "\(ns):block/\(name)"
            }
        }

        let parent: String
        switch project.template {
        case .fullBlock:
            parent = "minecraft:block/cube_all"
        default:
            parent = "minecraft:block/cube"
        }

        return [
            "parent": parent,
            "textures": textures
        ]
    }

    private func createBlockstate(project: BlockProject) -> [String: Any] {
        return [
            "variants": [
                "": [
                    "model": "\(project.namespace):block/\(project.name)"
                ]
            ]
        ]
    }

    private func createPackMeta(project: BlockProject) -> [String: Any] {
        let packFormat: Int
        switch project.targetVersion {
        case .java:    packFormat = 15 // 1.20+
        case .bedrock: packFormat = 2
        }

        return [
            "pack": [
                "pack_format": packFormat,
                "description": "VoxelSprite: \(project.name)"
            ]
        ]
    }

    // MARK: - Rendering

    private func renderCanvasToCGImage(_ canvas: PixelCanvas, gridSize: Int) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: gridSize,
            height: gridSize,
            bitsPerComponent: 8,
            bytesPerRow: gridSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        if !transparentBackground {
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: gridSize, height: gridSize))
        }

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                if let color = canvas.pixel(at: x, y: y),
                   let components = color.cgColorComponents {
                    context.setFillColor(red: components.r,
                                         green: components.g,
                                         blue: components.b,
                                         alpha: components.a)
                    context.fill(CGRect(x: x, y: gridSize - 1 - y, width: 1, height: 1))
                }
            }
        }

        return context.makeImage()
    }

    private func cgImageToPNGData(_ image: CGImage) -> Data? {
        #if canImport(UIKit)
        return UIImage(cgImage: image).pngData()
        #elseif canImport(AppKit)
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }

    // MARK: - Aufräumen

    func cleanup() {
        if let url = exportedFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        for url in additionalExportURLs {
            try? FileManager.default.removeItem(at: url)
        }
        exportedFileURL = nil
        additionalExportURLs = []
        showShareSheet = false
        errorMessage = nil
        exportProgress = 0
        exportStatus = ""
    }
}

// MARK: - Fehlertypen

enum ExportError: LocalizedError {
    case destinationCreationFailed
    case frameRenderFailed
    case finalizationFailed
    case contextCreationFailed
    case imageCreationFailed
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .destinationCreationFailed: return "Datei konnte nicht erstellt werden"
        case .frameRenderFailed:         return "Face konnte nicht gerendert werden"
        case .finalizationFailed:        return "Datei konnte nicht gespeichert werden"
        case .contextCreationFailed:     return "Grafik-Kontext konnte nicht erstellt werden"
        case .imageCreationFailed:       return "Bild konnte nicht erzeugt werden"
        case .pngEncodingFailed:         return "PNG-Kodierung fehlgeschlagen"
        }
    }
}
