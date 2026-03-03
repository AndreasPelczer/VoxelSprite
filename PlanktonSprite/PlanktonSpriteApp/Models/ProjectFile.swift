//
//  ProjectFile.swift
//  PlanktonSpriteApp
//
//  Created by Andreas Pelczer on 27.02.26.
//

import SwiftUI
import UniformTypeIdentifiers

/// Serialisierbares Dateiformat für .plankton Dateien.
/// Wandelt das AnimationProject in JSON-kompatible Daten um.
/// Farben werden als Hex-Strings gespeichert, nil = transparent.
struct ProjectFile: Codable {

    let version: Int
    var name: String
    var fps: Int
    var gridSize: Int
    var loopAnimation: Bool?
    var frames: [FrameData]

    /// Ein einzelner Frame als serialisierbare Pixeldaten
    struct FrameData: Codable {
        /// 2D Array: pixels[y][x] – Hex-Strings oder nil
        var pixels: [[String?]]
        /// Per-Frame Dauer in Millisekunden (nil = global FPS)
        var durationMs: Int?
    }

    // MARK: - Von AnimationProject → ProjectFile

    /// Konvertiert ein AnimationProject in ein speicherbares Format
    init(from project: AnimationProject) {
        self.version = 1
        self.name = project.name
        self.fps = project.fps
        self.gridSize = project.gridSize
        self.loopAnimation = project.loopAnimation
        self.frames = project.frames.map { frame in
            FrameData(
                pixels: frame.canvas.pixels.map { row in
                    row.map { color in
                        color.flatMap { c in
                            guard let comp = c.cgColorComponents else { return nil }
                            return String(format: "#%02X%02X%02X%02X",
                                Int(comp.r * 255),
                                Int(comp.g * 255),
                                Int(comp.b * 255),
                                Int(comp.a * 255))
                        }
                    }
                },
                durationMs: frame.durationMs
            )
        }
    }

    // MARK: - Von ProjectFile → AnimationProject

    /// Konvertiert die gespeicherten Daten zurück in ein AnimationProject
    func toProject() -> AnimationProject {
        var project = AnimationProject(name: name, gridSize: gridSize)
        project.fps = fps
        project.loopAnimation = loopAnimation ?? true
        project.frames = frames.map { frameData in
            var frame = SpriteFrame(gridSize: gridSize)
            var canvas = PixelCanvas(gridSize: gridSize)
            for (y, row) in frameData.pixels.enumerated() {
                for (x, hexString) in row.enumerated() {
                    if let hex = hexString {
                        canvas.setPixel(at: x, y: y, color: Color(hex: hex))
                    }
                }
            }
            frame.canvas = canvas
            frame.durationMs = frameData.durationMs
            return frame
        }
        if project.frames.isEmpty {
            project.frames = [SpriteFrame(gridSize: gridSize)]
        }
        return project
    }
}

// MARK: - FileDocument Wrapper

/// SwiftUI FileDocument-Wrapper für plattformübergreifendes Speichern/Öffnen.
struct PlanktonDocument: FileDocument {

    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "plankton") ?? .json]
    }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Color Hex Extension

extension Color {
    /// Erzeugt eine Color aus einem Hex-String.
    /// Unterstützt #RRGGBB und #RRGGBBAA.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: Double
        if hex.count == 8 {
            r = Double((int >> 24) & 0xFF) / 255
            g = Double((int >> 16) & 0xFF) / 255
            b = Double((int >> 8) & 0xFF) / 255
            a = Double(int & 0xFF) / 255
        } else {
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = 1
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
