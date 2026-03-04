//
//  ExportViewModel.swift
//  VoxelSprite
//
//  Zuständig für Minecraft Resourcepack Export:
//  - Einzelne Face-PNGs (16×16)
//  - Animierte Texturen (Vertikaler Strip + .mcmeta)
//  - Blockstate mit Rotations-Varianten
//  - CTM Export (Tiles + .properties)
//  - block.json / blockstate.json
//  - Item-Texturen + item.json
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

    // MARK: - Referenzen

    private weak var blockViewModel: BlockViewModel?
    private weak var itemViewModel: ItemViewModel?

    // MARK: - Init

    init() {}

    func connect(to blockViewModel: BlockViewModel) {
        self.blockViewModel = blockViewModel
    }

    func connect(to itemViewModel: ItemViewModel) {
        self.itemViewModel = itemViewModel
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
            let face = project.face(for: faceType)

            if face.isAnimated && project.ctmMethod == .none {
                // Animierte Textur: Vertikaler Strip
                guard let stripImage = renderAnimatedStrip(face: face, gridSize: project.gridSize) else {
                    throw ExportError.frameRenderFailed
                }
                guard let pngData = cgImageToPNGData(stripImage) else {
                    throw ExportError.pngEncodingFailed
                }

                let fileName = "\(project.name)_\(faceType.rawValue.lowercased()).png"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try pngData.write(to: url, options: .atomic)
                urls.append(url)

                // .mcmeta
                let mcmetaData = try createAnimationMcmetaData(face: face)
                let mcmetaURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(fileName).mcmeta")
                try mcmetaData.write(to: mcmetaURL, options: .atomic)
                urls.append(mcmetaURL)
            } else {
                // Statische Textur (erster Frame)
                let canvas = face.canvas
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
            }

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

        // 3. Blockstate JSON (mit Rotations-Varianten)
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

        // 5. CTM Export (wenn aktiviert)
        if project.ctmMethod != .none {
            DispatchQueue.main.async { [weak self] in
                self?.exportProgress = 0.9
                self?.exportStatus = "CTM…"
            }
            try exportCTMFiles(project: project, packDir: packDir)
        }

        return packDir
    }

    /// Exportiert die Face-Texturen und gibt die Textur-Pfade zurück
    private func exportTextures(project: BlockProject, to directory: URL) throws -> [FaceType: String] {
        var textureNames: [FaceType: String] = [:]

        // Prüfen welche Faces identische Texturen haben (Template-Optimierung)
        let uniqueTextures = findUniqueTextures(project: project)

        for (faceType, textureName) in uniqueTextures {
            let face = project.face(for: faceType)

            if face.isAnimated && project.ctmMethod == .none {
                // Animierte Textur: Vertikaler Strip + .mcmeta
                guard let stripImage = renderAnimatedStrip(face: face, gridSize: project.gridSize) else {
                    throw ExportError.frameRenderFailed
                }
                guard let pngData = cgImageToPNGData(stripImage) else {
                    throw ExportError.pngEncodingFailed
                }

                let fileName = "\(textureName).png"
                try pngData.write(to: directory.appendingPathComponent(fileName), options: .atomic)

                // .mcmeta
                let mcmetaData = try createAnimationMcmetaData(face: face)
                try mcmetaData.write(to: directory.appendingPathComponent("\(fileName).mcmeta"), options: .atomic)
            } else {
                // Statische Textur (erster Frame)
                let canvas = face.canvas
                guard let cgImage = renderCanvasToCGImage(canvas, gridSize: project.gridSize) else {
                    throw ExportError.frameRenderFailed
                }
                guard let pngData = cgImageToPNGData(cgImage) else {
                    throw ExportError.pngEncodingFailed
                }

                let fileName = "\(textureName).png"
                try pngData.write(to: directory.appendingPathComponent(fileName), options: .atomic)
            }
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

    // MARK: - Animation Rendering

    /// Rendert alle Frames eines Faces als vertikalen Strip (Minecraft-Format)
    private func renderAnimatedStrip(face: BlockFace, gridSize: Int) -> CGImage? {
        let frameCount = face.frames.count
        guard frameCount > 0 else { return nil }

        let width = gridSize
        let totalHeight = gridSize * frameCount

        guard let context = CGContext(
            data: nil,
            width: width,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        if !transparentBackground {
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: totalHeight))
        }

        for (frameIndex, canvas) in face.frames.enumerated() {
            // CGContext hat Ursprung unten-links
            // Frame 0 soll oben sein, also y-Offset umkehren
            let yOffset = (frameCount - 1 - frameIndex) * gridSize

            for y in 0..<gridSize {
                for x in 0..<gridSize {
                    if let color = canvas.pixel(at: x, y: y),
                       let c = color.cgColorComponents {
                        context.setFillColor(red: c.r, green: c.g, blue: c.b, alpha: c.a)
                        context.fill(CGRect(
                            x: x,
                            y: yOffset + (gridSize - 1 - y),
                            width: 1,
                            height: 1
                        ))
                    }
                }
            }
        }

        return context.makeImage()
    }

    /// Erstellt .mcmeta Daten für Animation
    private func createAnimationMcmetaData(face: BlockFace) throws -> Data {
        let mcmeta = createAnimationMcmeta(face: face)
        return try JSONSerialization.data(withJSONObject: mcmeta, options: .prettyPrinted)
    }

    private func createAnimationMcmeta(face: BlockFace) -> [String: Any] {
        var animation: [String: Any] = [
            "frametime": face.frameTime
        ]
        if face.interpolate {
            animation["interpolate"] = true
        }
        return ["animation": animation]
    }

    // MARK: - CTM Export

    /// Exportiert CTM-Dateien (OptiFine/Continuity kompatibel)
    private func exportCTMFiles(project: BlockProject, packDir: URL) throws {
        let fm = FileManager.default

        // CTM-Verzeichnis: assets/{namespace}/optifine/ctm/{blockname}/
        let ctmDir = packDir
            .appendingPathComponent("assets/\(project.namespace)/optifine/ctm/\(project.name)")
        try fm.createDirectory(at: ctmDir, withIntermediateDirectories: true)

        // Primäres Face bestimmen (für Tiles)
        let primaryFaceType = determinePrimaryFace(project: project)
        let face = project.face(for: primaryFaceType)

        // Tiles exportieren
        for (index, tileCanvas) in face.frames.enumerated() {
            guard let cgImage = renderCanvasToCGImage(tileCanvas, gridSize: project.gridSize) else {
                throw ExportError.frameRenderFailed
            }
            guard let pngData = cgImageToPNGData(cgImage) else {
                throw ExportError.pngEncodingFailed
            }
            try pngData.write(to: ctmDir.appendingPathComponent("\(index).png"), options: .atomic)
        }

        // Properties-Datei
        let properties = createCTMProperties(project: project, tileCount: face.frames.count)
        try properties.write(
            to: ctmDir.appendingPathComponent("\(project.name).properties"),
            atomically: true,
            encoding: .utf8
        )
    }

    /// Bestimmt das primäre Face für CTM-Tiles
    private func determinePrimaryFace(project: BlockProject) -> FaceType {
        switch project.template {
        case .fullBlock:  return .north
        case .grassStyle: return .north  // Seiten-Textur
        case .pillar:     return .north  // Seiten-Textur
        case .slab:       return .north
        case .custom:     return .north
        }
    }

    /// Erstellt die CTM .properties Datei
    private func createCTMProperties(project: BlockProject, tileCount: Int) -> String {
        var lines: [String] = []

        switch project.ctmMethod {
        case .none:
            return ""

        case .random:
            lines.append("method=random")
            if tileCount > 0 {
                lines.append("tiles=0-\(tileCount - 1)")
            }

        case .repeat_:
            lines.append("method=repeat")
            if tileCount > 0 {
                lines.append("tiles=0-\(tileCount - 1)")
            }
            lines.append("width=\(project.ctmRepeatWidth)")
            lines.append("height=\(project.ctmRepeatHeight)")
        }

        lines.append("matchBlocks=\(project.namespace):\(project.name)")
        return lines.joined(separator: "\n") + "\n"
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

    /// Blockstate JSON mit Rotations-Varianten
    private func createBlockstate(project: BlockProject) -> [String: Any] {
        let modelRef = "\(project.namespace):block/\(project.name)"

        switch project.rotation {
        case .none:
            return [
                "variants": [
                    "": ["model": modelRef]
                ]
            ]

        case .directional:
            return [
                "variants": [
                    "facing=north": ["model": modelRef],
                    "facing=east":  ["model": modelRef, "y": 90],
                    "facing=south": ["model": modelRef, "y": 180],
                    "facing=west":  ["model": modelRef, "y": 270]
                ]
            ]

        case .sixWay:
            return [
                "variants": [
                    "facing=north": ["model": modelRef],
                    "facing=east":  ["model": modelRef, "y": 90],
                    "facing=south": ["model": modelRef, "y": 180],
                    "facing=west":  ["model": modelRef, "y": 270],
                    "facing=up":    ["model": modelRef, "x": 270],
                    "facing=down":  ["model": modelRef, "x": 90]
                ]
            ]

        case .random:
            return [
                "variants": [
                    "": [
                        ["model": modelRef],
                        ["model": modelRef, "y": 90],
                        ["model": modelRef, "y": 180],
                        ["model": modelRef, "y": 270]
                    ]
                ]
            ]
        }
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

    // MARK: - Item PNG Export

    /// Exportiert das Item als PNG (composited)
    func exportItemPNG() {
        guard let itemVM = itemViewModel else { return }

        isExporting = true
        errorMessage = nil
        exportProgress = 0
        exportStatus = "Item wird exportiert…"

        let snapshot = itemVM.project

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let urls = try self.createItemPNGs(project: snapshot)

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

    private func createItemPNGs(project: ItemProject) throws -> [URL] {
        var urls: [URL] = []

        for (index, layer) in project.layers.enumerated() {
            guard let cgImage = renderCanvasToCGImage(layer, gridSize: project.gridSize) else {
                throw ExportError.frameRenderFailed
            }
            guard let pngData = cgImageToPNGData(cgImage) else {
                throw ExportError.pngEncodingFailed
            }

            let texName = project.textureName(for: index)
            let fileName = "\(texName).png"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try pngData.write(to: url, options: .atomic)
            urls.append(url)

            DispatchQueue.main.async { [weak self] in
                self?.exportProgress = Double(index + 1) / Double(project.layers.count) * 0.9
                self?.exportStatus = "Layer \(index)…"
            }
        }

        return urls
    }

    // MARK: - Item Resourcepack Export

    /// Exportiert ein Item-Resourcepack
    func exportItemResourcepack() {
        guard let itemVM = itemViewModel else { return }

        isExporting = true
        errorMessage = nil
        exportProgress = 0
        exportStatus = "Item-Resourcepack wird erstellt…"

        let snapshot = itemVM.project

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let url = try self.createItemResourcepack(project: snapshot)

                DispatchQueue.main.async {
                    self.exportProgress = 1.0
                    self.exportStatus = "Fertig!"
                    self.exportedFileURL = url
                    self.showShareSheet = true
                    self.isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Item-Export fehlgeschlagen: \(error.localizedDescription)"
                    self.isExporting = false
                    self.exportProgress = 0
                    self.exportStatus = ""
                }
            }
        }
    }

    private func createItemResourcepack(project: ItemProject) throws -> URL {
        let fm = FileManager.default
        let baseName = uniqueFileName(base: project.name, ext: "")
        let packDir = fm.temporaryDirectory.appendingPathComponent("resourcepack_item_\(baseName)")

        // Ordnerstruktur
        let texturesDir = packDir
            .appendingPathComponent("assets/\(project.namespace)/textures/item")
        let modelsDir = packDir
            .appendingPathComponent("assets/\(project.namespace)/models/item")

        try fm.createDirectory(at: texturesDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        DispatchQueue.main.async { [weak self] in
            self?.exportProgress = 0.1
            self?.exportStatus = "Texturen…"
        }

        // 1. Texturen exportieren (pro Layer)
        for (index, layer) in project.layers.enumerated() {
            guard let cgImage = renderCanvasToCGImage(layer, gridSize: project.gridSize) else {
                throw ExportError.frameRenderFailed
            }
            guard let pngData = cgImageToPNGData(cgImage) else {
                throw ExportError.pngEncodingFailed
            }

            let texName = project.textureName(for: index)
            try pngData.write(to: texturesDir.appendingPathComponent("\(texName).png"), options: .atomic)
        }

        DispatchQueue.main.async { [weak self] in
            self?.exportProgress = 0.5
            self?.exportStatus = "Item Model…"
        }

        // 2. Item Model JSON
        let modelJSON = createItemModel(project: project)
        let modelData = try JSONSerialization.data(withJSONObject: modelJSON, options: .prettyPrinted)
        try modelData.write(to: modelsDir.appendingPathComponent("\(project.name).json"), options: .atomic)

        DispatchQueue.main.async { [weak self] in
            self?.exportProgress = 0.85
            self?.exportStatus = "pack.mcmeta…"
        }

        // 3. pack.mcmeta
        let packMeta = createItemPackMeta(project: project)
        let packMetaData = try JSONSerialization.data(withJSONObject: packMeta, options: .prettyPrinted)
        try packMetaData.write(to: packDir.appendingPathComponent("pack.mcmeta"), options: .atomic)

        return packDir
    }

    /// Item Model JSON
    private func createItemModel(project: ItemProject) -> [String: Any] {
        var textures: [String: String] = [:]

        for index in 0..<project.layers.count {
            let texName = project.textureName(for: index)
            textures["layer\(index)"] = "\(project.namespace):item/\(texName)"
        }

        return [
            "parent": project.displayType.parent,
            "textures": textures
        ]
    }

    private func createItemPackMeta(project: ItemProject) -> [String: Any] {
        let packFormat: Int
        switch project.targetVersion {
        case .java:    packFormat = 15
        case .bedrock: packFormat = 2
        }

        return [
            "pack": [
                "pack_format": packFormat,
                "description": "VoxelSprite Item: \(project.name)"
            ]
        ]
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
