//
//  VoxelProjectFile.swift
//  VoxelSprite
//
//  Serialisierbares Dateiformat für .voxel Dateien.
//  Wandelt das BlockProject in JSON-kompatible Daten um.
//  Version 2: Unterstützt Animations-Frames, Rotation, CTM.
//

import SwiftUI
import UniformTypeIdentifiers

/// Serialisierbares Dateiformat für .voxel Dateien
struct VoxelProjectFile: Codable {

    let version: Int
    var name: String
    var gridSize: Int
    var template: String
    var namespace: String
    var targetVersion: String
    var faces: [String: FaceData]

    // V2: Neue Felder (optional für Abwärtskompatibilität)
    var rotation: String?
    var ctmMethod: String?
    var ctmRepeatWidth: Int?
    var ctmRepeatHeight: Int?

    /// Pixeldaten einer Face
    struct FaceData: Codable {
        var pixels: [[String?]]             // Erster Frame (Abwärtskompatibilität)
        var additionalFrames: [[[String?]]]? // Weitere Frames (optional)
        var frameTime: Int?                  // Ticks pro Frame
        var interpolate: Bool?               // Interpolation
    }

    // MARK: - Von BlockProject → VoxelProjectFile

    init(from project: BlockProject) {
        self.version = 2
        self.name = project.name
        self.gridSize = project.gridSize
        self.template = project.template.rawValue
        self.namespace = project.namespace
        self.targetVersion = project.targetVersion.rawValue

        // V2 Felder
        self.rotation = project.rotation.rawValue
        self.ctmMethod = project.ctmMethod.rawValue
        self.ctmRepeatWidth = project.ctmRepeatWidth
        self.ctmRepeatHeight = project.ctmRepeatHeight

        var facesDict: [String: FaceData] = [:]
        for faceType in FaceType.allCases {
            let face = project.face(for: faceType)

            // Erster Frame als `pixels`
            let firstFrameData = Self.canvasToPixels(face.frames.first ?? PixelCanvas(gridSize: project.gridSize))

            // Zusätzliche Frames
            var additionalFrames: [[[String?]]]?
            if face.frames.count > 1 {
                additionalFrames = face.frames.dropFirst().map { Self.canvasToPixels($0) }
            }

            facesDict[faceType.rawValue] = FaceData(
                pixels: firstFrameData,
                additionalFrames: additionalFrames,
                frameTime: face.frameTime != 2 ? face.frameTime : nil,
                interpolate: face.interpolate ? true : nil
            )
        }
        self.faces = facesDict
    }

    /// Konvertiert ein PixelCanvas zu einem 2D-Array von Hex-Strings
    private static func canvasToPixels(_ canvas: PixelCanvas) -> [[String?]] {
        canvas.pixels.map { row in
            row.map { color -> String? in
                guard let c = color, let comp = c.cgColorComponents else { return nil }
                return String(format: "#%02X%02X%02X%02X",
                    Int(comp.r * 255),
                    Int(comp.g * 255),
                    Int(comp.b * 255),
                    Int(comp.a * 255))
            }
        }
    }

    // MARK: - Von VoxelProjectFile → BlockProject

    func toProject() -> BlockProject {
        var project = BlockProject(
            name: name,
            gridSize: gridSize,
            template: BlockTemplate(rawValue: template) ?? .custom,
            namespace: namespace,
            targetVersion: BlockProject.TargetVersion(rawValue: targetVersion) ?? .java,
            rotation: rotation.flatMap { BlockRotation(rawValue: $0) } ?? .none,
            ctmMethod: ctmMethod.flatMap { CTMMethod(rawValue: $0) } ?? .none,
            ctmRepeatWidth: ctmRepeatWidth ?? 2,
            ctmRepeatHeight: ctmRepeatHeight ?? 2
        )

        for faceType in FaceType.allCases {
            guard let faceData = faces[faceType.rawValue] else { continue }

            // Erster Frame
            let firstCanvas = Self.pixelsToCanvas(faceData.pixels, gridSize: gridSize)

            // Alle Frames zusammenbauen
            var frames = [firstCanvas]
            if let additionalFrames = faceData.additionalFrames {
                for framePixels in additionalFrames {
                    frames.append(Self.pixelsToCanvas(framePixels, gridSize: gridSize))
                }
            }

            project.faces[faceType]?.frames = frames
            project.faces[faceType]?.frameTime = faceData.frameTime ?? 2
            project.faces[faceType]?.interpolate = faceData.interpolate ?? false
        }

        return project
    }

    /// Konvertiert ein 2D-Array von Hex-Strings zu einem PixelCanvas
    private static func pixelsToCanvas(_ pixels: [[String?]], gridSize: Int) -> PixelCanvas {
        var canvas = PixelCanvas(gridSize: gridSize)
        for (y, row) in pixels.enumerated() {
            for (x, hexString) in row.enumerated() {
                if let hex = hexString {
                    canvas.setPixel(at: x, y: y, color: Color(hex: hex))
                }
            }
        }
        return canvas
    }
}

// MARK: - FileDocument Wrapper

/// SwiftUI FileDocument-Wrapper für .voxel Dateien
struct VoxelDocument: FileDocument {

    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "voxel") ?? .json]
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
