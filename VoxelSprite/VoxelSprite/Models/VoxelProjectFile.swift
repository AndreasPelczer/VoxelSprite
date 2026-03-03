//
//  VoxelProjectFile.swift
//  VoxelSprite
//
//  Serialisierbares Dateiformat für .voxel Dateien.
//  Wandelt das BlockProject in JSON-kompatible Daten um.
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

    /// Pixeldaten einer Face
    struct FaceData: Codable {
        var pixels: [[String?]]
    }

    // MARK: - Von BlockProject → VoxelProjectFile

    init(from project: BlockProject) {
        self.version = 1
        self.name = project.name
        self.gridSize = project.gridSize
        self.template = project.template.rawValue
        self.namespace = project.namespace
        self.targetVersion = project.targetVersion.rawValue

        var facesDict: [String: FaceData] = [:]
        for faceType in FaceType.allCases {
            let canvas = project.canvas(for: faceType)
            let pixelData = canvas.pixels.map { row in
                row.map { color -> String? in
                    guard let c = color, let comp = c.cgColorComponents else { return nil }
                    return String(format: "#%02X%02X%02X%02X",
                        Int(comp.r * 255),
                        Int(comp.g * 255),
                        Int(comp.b * 255),
                        Int(comp.a * 255))
                }
            }
            facesDict[faceType.rawValue] = FaceData(pixels: pixelData)
        }
        self.faces = facesDict
    }

    // MARK: - Von VoxelProjectFile → BlockProject

    func toProject() -> BlockProject {
        var project = BlockProject(
            name: name,
            gridSize: gridSize,
            template: BlockTemplate(rawValue: template) ?? .custom,
            namespace: namespace,
            targetVersion: BlockProject.TargetVersion(rawValue: targetVersion) ?? .java
        )

        for faceType in FaceType.allCases {
            guard let faceData = faces[faceType.rawValue] else { continue }
            var canvas = PixelCanvas(gridSize: gridSize)
            for (y, row) in faceData.pixels.enumerated() {
                for (x, hexString) in row.enumerated() {
                    if let hex = hexString {
                        canvas.setPixel(at: x, y: y, color: Color(hex: hex))
                    }
                }
            }
            project.faces[faceType]?.canvas = canvas
        }

        return project
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
