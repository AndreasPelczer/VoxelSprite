//
//  ExportViewModel.swift
//  PlanktonSpriteApp
//
//  Created by Andreas Pelczer on 27.02.26.
//

import SwiftUI
import Combine
import ImageIO
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Zuständig für alle Export-Operationen:
/// Animiertes GIF und PNG-Spritesheet.
/// Stellt die Daten bereit, die der ShareSheet braucht.
class ExportViewModel: ObservableObject {

    // MARK: - Spritesheet Layout

    /// Layout-Optionen für Spritesheet-Export
    enum SpritesheetLayout: String, CaseIterable, Identifiable {
        case horizontal = "Horizontal"
        case vertical = "Vertikal"
        case grid = "Grid"

        var id: String { rawValue }
    }

    /// Engine-Presets für JSON-Meta-Export
    enum EnginePreset: String, CaseIterable, Identifiable {
        case generic = "Generic"
        case unity = "Unity"
        case godot = "Godot"
        case spriteKit = "SpriteKit"

        var id: String { rawValue }
    }

    // MARK: - Published State

    /// Ist gerade ein Export am Laufen?
    @Published var isExporting: Bool = false

    /// Soll das Share Sheet angezeigt werden?
    @Published var showShareSheet: Bool = false

    /// Die exportierte Datei als URL – wird dem ShareSheet übergeben
    @Published var exportedFileURL: URL?

    /// Zusätzliche exportierte Dateien (z.B. JSON neben PNG)
    @Published var additionalExportURLs: [URL] = []

    /// Fehlermeldung falls der Export schiefgeht
    @Published var errorMessage: String?

    /// Exportfortschritt (0.0–1.0)
    @Published var exportProgress: Double = 0

    /// Statustext während des Exports
    @Published var exportStatus: String = ""

    /// GIF mit transparentem Hintergrund exportieren
    @Published var transparentBackground: Bool = false

    /// Gewähltes Spritesheet-Layout
    @Published var spritesheetLayout: SpritesheetLayout = .horizontal

    /// Gewähltes Engine-Preset
    @Published var enginePreset: EnginePreset = .generic

    /// Custom Padding zwischen Frames im Spritesheet
    @Published var spritesheetPadding: Int = 0

    // MARK: - Referenz

    private weak var frameViewModel: FrameViewModel?

    // MARK: - Init

    init() {}

    func connect(to frameViewModel: FrameViewModel) {
        self.frameViewModel = frameViewModel
    }

    // MARK: - Unique Filename

    /// Erzeugt einen kollisionsfreien Dateinamen mit Timestamp + UUID-Suffix
    private func uniqueFileName(base: String, ext: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let shortID = UUID().uuidString.prefix(4)
        return "\(base)_\(timestamp)_\(shortID).\(ext)"
    }
    
    // MARK: - GIF Export
    
    /// Erzeugt ein animiertes GIF aus allen Frames.
    func exportGIF() {
        guard let frameVM = frameViewModel else { return }

        isExporting = true
        errorMessage = nil
        exportProgress = 0
        exportStatus = "GIF wird erstellt…"

        // Snapshot auf MainActor: alle Value-Types werden hier deep-copied.
        // Ab hier arbeitet der Background-Thread nur mit dieser Kopie.
        let snapshot = frameVM.project
        let frames = snapshot.frames
        let fps = snapshot.fps
        let name = snapshot.name
        let gridSize = snapshot.gridSize
        let loop = snapshot.loopAnimation
        let transparentBG = transparentBackground

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let url = try self.createGIF(
                    frames: frames,
                    fps: fps,
                    name: name,
                    gridSize: gridSize,
                    loop: loop,
                    transparentBackground: transparentBG
                )

                DispatchQueue.main.async {
                    self.exportProgress = 1.0
                    self.exportStatus = "Fertig!"
                    self.exportedFileURL = url
                    self.showShareSheet = true
                    self.isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "GIF-Export fehlgeschlagen: \(error.localizedDescription)"
                    self.isExporting = false
                    self.exportProgress = 0
                    self.exportStatus = ""
                }
            }
        }
    }

    /// Baut die GIF-Datei zusammen.
    private func createGIF(frames: [SpriteFrame], fps: Int, name: String, gridSize: Int, loop: Bool, transparentBackground: Bool) throws -> URL {
        let fileName = uniqueFileName(base: "\(name)_animation", ext: "gif")
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        guard let destination = CGImageDestinationCreateWithURL(
            fileURL as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else {
            throw ExportError.destinationCreationFailed
        }

        // Loop: 0 = unendlich, 1 = einmal
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: loop ? 0 : 1
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        let defaultDelay = 1.0 / Double(fps)

        for (index, frame) in frames.enumerated() {
            guard let cgImage = renderFrameToCGImage(frame.canvas, gridSize: gridSize, transparentBackground: transparentBackground) else {
                throw ExportError.frameRenderFailed
            }

            // Per-Frame Duration: wenn gesetzt, in Sekunden umrechnen
            let delay = frame.durationMs.map { Double($0) / 1000.0 } ?? defaultDelay

            let frameProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFDelayTime as String: delay
                ]
            ]

            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)

            let progress = Double(index + 1) / Double(frames.count)
            DispatchQueue.main.async { [weak self] in
                self?.exportProgress = progress * 0.9 // 90% für Frames, 10% für Finalize
                self?.exportStatus = "Frame \(index + 1)/\(frames.count)…"
            }
        }

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.finalizationFailed
        }

        return fileURL
    }
    
    // MARK: - Spritesheet Export
    
    /// Erzeugt ein PNG-Spritesheet mit optionalem JSON-Meta.
    func exportSpritesheet() {
        guard let frameVM = frameViewModel else { return }

        isExporting = true
        errorMessage = nil
        exportProgress = 0
        exportStatus = "Spritesheet wird erstellt…"

        // Snapshot auf MainActor: deep copy aller Value-Types
        let snapshot = frameVM.project
        let frames = snapshot.frames
        let name = snapshot.name
        let gridSize = snapshot.gridSize
        let fps = snapshot.fps
        let layout = spritesheetLayout
        let padding = spritesheetPadding
        let preset = enginePreset

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let (pngURL, jsonURL) = try self.createSpritesheet(
                    frames: frames,
                    name: name,
                    gridSize: gridSize,
                    fps: fps,
                    layout: layout,
                    padding: padding,
                    preset: preset
                )

                DispatchQueue.main.async {
                    self.exportProgress = 1.0
                    self.exportStatus = "Fertig!"
                    self.exportedFileURL = pngURL
                    if let jsonURL = jsonURL {
                        self.additionalExportURLs = [jsonURL]
                    }
                    self.showShareSheet = true
                    self.isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Spritesheet-Export fehlgeschlagen: \(error.localizedDescription)"
                    self.isExporting = false
                    self.exportProgress = 0
                    self.exportStatus = ""
                }
            }
        }
    }

    /// Berechnet Spritesheet-Dimensionen basierend auf Layout
    private func spritesheetDimensions(frameCount: Int, gridSize: Int, padding: Int, layout: SpritesheetLayout) -> (width: Int, height: Int, columns: Int, rows: Int) {
        let cell = gridSize + padding
        switch layout {
        case .horizontal:
            return (cell * frameCount - padding, gridSize, frameCount, 1)
        case .vertical:
            return (gridSize, cell * frameCount - padding, 1, frameCount)
        case .grid:
            let cols = Int(ceil(sqrt(Double(frameCount))))
            let rows = Int(ceil(Double(frameCount) / Double(cols)))
            return (cell * cols - padding, cell * rows - padding, cols, rows)
        }
    }

    /// Baut das Spritesheet mit konfigurierbarem Layout.
    private func createSpritesheet(frames: [SpriteFrame], name: String, gridSize: Int, fps: Int, layout: SpritesheetLayout, padding: Int, preset: EnginePreset) throws -> (URL, URL?) {
        let dims = spritesheetDimensions(frameCount: frames.count, gridSize: gridSize, padding: padding, layout: layout)

        guard let context = CGContext(
            data: nil,
            width: dims.width,
            height: dims.height,
            bitsPerComponent: 8,
            bytesPerRow: dims.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ExportError.contextCreationFailed
        }

        let cell = gridSize + padding

        for (index, frame) in frames.enumerated() {
            let col: Int
            let row: Int
            switch layout {
            case .horizontal:
                col = index; row = 0
            case .vertical:
                col = 0; row = index
            case .grid:
                col = index % dims.columns; row = index / dims.columns
            }

            let offsetX = col * cell
            let offsetY = row * cell

            for y in 0..<gridSize {
                for x in 0..<gridSize {
                    if let color = frame.canvas.pixel(at: x, y: y),
                       let components = color.cgColorComponents {
                        context.setFillColor(red: components.r,
                                             green: components.g,
                                             blue: components.b,
                                             alpha: components.a)
                        context.fill(CGRect(x: offsetX + x, y: dims.height - 1 - (offsetY + y), width: 1, height: 1))
                    }
                }
            }
        }

        guard let cgImage = context.makeImage() else {
            throw ExportError.imageCreationFailed
        }

        let pngFileName = uniqueFileName(base: "\(name)_spritesheet", ext: "png")
        let pngURL = FileManager.default.temporaryDirectory.appendingPathComponent(pngFileName)

        guard let pngData = cgImageToPNGData(cgImage) else {
            throw ExportError.pngEncodingFailed
        }
        try pngData.write(to: pngURL, options: .atomic)

        // JSON Meta-Daten generieren
        let jsonURL = try createSpritesheetMeta(
            name: name,
            frames: frames,
            gridSize: gridSize,
            fps: fps,
            layout: layout,
            padding: padding,
            dims: dims,
            preset: preset,
            pngFileName: pngFileName
        )

        return (pngURL, jsonURL)
    }

    /// Erzeugt JSON-Meta-Daten für das Spritesheet, angepasst an Engine-Preset.
    private func createSpritesheetMeta(name: String, frames: [SpriteFrame], gridSize: Int, fps: Int, layout: SpritesheetLayout, padding: Int, dims: (width: Int, height: Int, columns: Int, rows: Int), preset: EnginePreset, pngFileName: String) throws -> URL {
        let cell = gridSize + padding

        var frameEntries: [[String: Any]] = []
        for (index, frame) in frames.enumerated() {
            let col: Int
            let row: Int
            switch layout {
            case .horizontal: col = index; row = 0
            case .vertical: col = 0; row = index
            case .grid: col = index % dims.columns; row = index / dims.columns
            }

            let duration = frame.durationMs ?? Int(1000.0 / Double(fps))

            var entry: [String: Any] = [
                "index": index,
                "x": col * cell,
                "y": row * cell,
                "width": gridSize,
                "height": gridSize,
                "duration_ms": duration
            ]

            switch preset {
            case .unity:
                entry["pivot"] = ["x": 0.5, "y": 0.5]
                entry["border"] = ["x": 0, "y": 0, "z": 0, "w": 0]
            case .godot:
                entry["region"] = [
                    "x": col * cell,
                    "y": row * cell,
                    "w": gridSize,
                    "h": gridSize
                ]
            case .spriteKit:
                // SpriteKit verwendet textureRect in normalisierten Koordinaten
                entry["textureRect"] = [
                    "x": Double(col * cell) / Double(dims.width),
                    "y": Double(row * cell) / Double(dims.height),
                    "width": Double(gridSize) / Double(dims.width),
                    "height": Double(gridSize) / Double(dims.height)
                ]
            case .generic:
                break
            }

            frameEntries.append(entry)
        }

        var meta: [String: Any] = [
            "formatVersion": 1,
            "generator": "PlanktonSprite",
            "image": pngFileName,
            "format": "RGBA8888",
            "size": ["w": dims.width, "h": dims.height],
            "frameSize": ["w": gridSize, "h": gridSize],
            "frameCount": frames.count,
            "fps": fps,
            "layout": layout.rawValue.lowercased(),
            "columns": dims.columns,
            "rows": dims.rows,
            "padding": padding,
            "preset": preset.rawValue,
            "frames": frameEntries
        ]

        switch preset {
        case .unity:
            meta["pixelsPerUnit"] = 16
            meta["filterMode"] = "Point"
            meta["wrapMode"] = "Clamp"
        case .godot:
            meta["resource_type"] = "AtlasTexture"
            meta["flags"] = 0
        case .spriteKit:
            meta["textureAtlas"] = name
        case .generic:
            break
        }

        let jsonData = try JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys])
        let jsonFileName = uniqueFileName(base: "\(name)_spritesheet", ext: "json")
        let jsonURL = FileManager.default.temporaryDirectory.appendingPathComponent(jsonFileName)
        try jsonData.write(to: jsonURL, options: .atomic)

        return jsonURL
    }
    
    // MARK: - Frame zu CGImage rendern
    
    /// Wandelt ein PixelCanvas in ein CGImage um.
    /// Jeder Pixel wird 1:1 übertragen – keine Skalierung.
    private func renderFrameToCGImage(_ canvas: PixelCanvas, gridSize: Int, transparentBackground: Bool = false) -> CGImage? {
        let size = gridSize

        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Weißer Hintergrund wenn nicht transparent
        if !transparentBackground {
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        }

        for y in 0..<size {
            for x in 0..<size {
                if let color = canvas.pixel(at: x, y: y),
                   let components = color.cgColorComponents {
                    context.setFillColor(red: components.r,
                                         green: components.g,
                                         blue: components.b,
                                         alpha: components.a)
                    context.fill(CGRect(x: x, y: size - 1 - y, width: 1, height: 1))
                }
            }
        }

        return context.makeImage()
    }
    
    // MARK: - PNG Konvertierung
    
    /// Wandelt ein CGImage in PNG-Daten um.
    /// Plattformunabhängig – funktioniert auf macOS und iOS.
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
    
    /// Löscht die temporäre Datei nach dem Teilen
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

/// Eigene Error-Typen für aussagekräftige Fehlermeldungen
enum ExportError: LocalizedError {
    case destinationCreationFailed
    case frameRenderFailed
    case finalizationFailed
    case contextCreationFailed
    case imageCreationFailed
    case pngEncodingFailed
    
    var errorDescription: String? {
        switch self {
        case .destinationCreationFailed: return "GIF-Datei konnte nicht erstellt werden"
        case .frameRenderFailed:         return "Frame konnte nicht gerendert werden"
        case .finalizationFailed:        return "GIF konnte nicht gespeichert werden"
        case .contextCreationFailed:     return "Grafik-Kontext konnte nicht erstellt werden"
        case .imageCreationFailed:       return "Bild konnte nicht erzeugt werden"
        case .pngEncodingFailed:         return "PNG-Kodierung fehlgeschlagen"
        }
    }
}

// MARK: - Color Extension

/// Hilfsfunktion um SwiftUI Color in CGColor-Komponenten zu zerlegen.
/// Auf macOS geht das über NSColor.
extension Color {
    
    /// Extrahiert RGBA-Werte aus einer SwiftUI Color.
    /// Konvertiert erst in den sRGB-Farbraum, damit die Werte
    /// konsistent sind – macOS arbeitet intern mit verschiedenen
    /// Farbräumen (Display P3, Generic RGB, etc.).
    var cgColorComponents: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        #if canImport(UIKit)
        let color = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (r, g, b, a)
        #elseif canImport(AppKit)
        // NSColor muss erst in sRGB konvertiert werden,
        // sonst crasht getRed() bei manchen Farbräumen
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
        #else
        return nil
        #endif
    }
}
