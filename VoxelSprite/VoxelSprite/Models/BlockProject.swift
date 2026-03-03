//
//  BlockProject.swift
//  VoxelSprite
//
//  Ein Projekt = ein Minecraft-Block mit 6 Faces.
//  Hält alle Faces und die Block-Einstellungen.
//

import SwiftUI

// MARK: - Block Template

/// Vordefinierte Block-Typen bestimmen, welche Faces
/// gleiche Texturen teilen können.
enum BlockTemplate: String, CaseIterable, Identifiable, Codable {
    case fullBlock   = "Vollblock"
    case grassStyle  = "Gras-Style"
    case slab        = "Slab"
    case pillar      = "Säule"
    case custom      = "Custom"

    var id: String { rawValue }

    /// Beschreibung für die UI
    var description: String {
        switch self {
        case .fullBlock:  return "Alle Seiten gleich"
        case .grassStyle: return "Top anders, Seiten gleich, Bottom anders"
        case .slab:       return "Halber Block"
        case .pillar:     return "Top/Bottom gleich, Seiten gleich"
        case .custom:     return "Jede Seite individuell"
        }
    }

    /// SF Symbol
    var iconName: String {
        switch self {
        case .fullBlock:  return "cube"
        case .grassStyle: return "leaf"
        case .slab:       return "rectangle.split.1x2"
        case .pillar:     return "cylinder"
        case .custom:     return "cube.transparent"
        }
    }
}

// MARK: - Block Project

/// Das komplette Block-Projekt.
/// Hält alle 6 Faces und die Projekt-Einstellungen.
struct BlockProject {

    // MARK: - Faces

    /// Die 6 Seiten des Blocks, in fester Reihenfolge.
    var faces: [FaceType: BlockFace]

    // MARK: - Einstellungen

    /// Name des Blocks – für Dateiexport und Minecraft-Resourcepack
    var name: String

    /// Rastergröße (immer 16 für Minecraft, aber konfigurierbar)
    var gridSize: Int

    /// Block-Template bestimmt welche Faces verlinkt sind
    var template: BlockTemplate

    /// Minecraft Namespace (z.B. "minecraft" oder eigener Mod-Namespace)
    var namespace: String

    /// Ziel-Version
    var targetVersion: TargetVersion

    // MARK: - Target Version

    enum TargetVersion: String, CaseIterable, Identifiable, Codable {
        case java    = "Java Edition 1.20+"
        case bedrock = "Bedrock Edition"

        var id: String { rawValue }

        var shortLabel: String {
            switch self {
            case .java:    return "Java"
            case .bedrock: return "Bedrock"
            }
        }
    }

    // MARK: - Init

    /// Erzeugt ein neues Block-Projekt mit 6 leeren Faces
    init(
        name: String = "custom_block",
        gridSize: Int = 16,
        template: BlockTemplate = .custom,
        namespace: String = "minecraft",
        targetVersion: TargetVersion = .java
    ) {
        self.name = name
        self.gridSize = gridSize
        self.template = template
        self.namespace = namespace
        self.targetVersion = targetVersion

        // Alle 6 Faces initialisieren
        var facesDict: [FaceType: BlockFace] = [:]
        for faceType in FaceType.allCases {
            facesDict[faceType] = BlockFace(type: faceType, gridSize: gridSize)
        }
        self.faces = facesDict
    }

    // MARK: - Face-Zugriff

    /// Sicherer Zugriff auf ein Face
    func face(for type: FaceType) -> BlockFace {
        faces[type] ?? BlockFace(type: type, gridSize: gridSize)
    }

    /// Canvas eines bestimmten Faces
    func canvas(for type: FaceType) -> PixelCanvas {
        face(for: type).canvas
    }

    /// Aktualisiert das Canvas eines Faces
    mutating func updateCanvas(for type: FaceType, canvas: PixelCanvas) {
        faces[type]?.canvas = canvas
    }

    // MARK: - Template-Operationen

    /// Kopiert das aktive Face auf alle verknüpften Faces
    /// gemäß dem aktuellen Template.
    mutating func applyTemplate(from sourceFace: FaceType) {
        guard let sourceCanvas = faces[sourceFace]?.canvas else { return }

        let linkedFaces: [FaceType]

        switch template {
        case .fullBlock:
            // Alle Faces bekommen die gleiche Textur
            linkedFaces = FaceType.allCases.filter { $0 != sourceFace }

        case .grassStyle:
            // Top = nur Top, Bottom = nur Bottom, Seiten teilen sich
            let sides: [FaceType] = [.north, .south, .east, .west]
            if sides.contains(sourceFace) {
                linkedFaces = sides.filter { $0 != sourceFace }
            } else {
                linkedFaces = []
            }

        case .pillar:
            // Top/Bottom teilen, Seiten teilen
            if sourceFace == .top || sourceFace == .bottom {
                linkedFaces = [.top, .bottom].filter { $0 != sourceFace }
            } else {
                linkedFaces = [.north, .south, .east, .west].filter { $0 != sourceFace }
            }

        case .slab, .custom:
            linkedFaces = []
        }

        for face in linkedFaces {
            faces[face]?.canvas = sourceCanvas
        }
    }

    // MARK: - Geordnete Faces

    /// Faces in der Reihenfolge von FaceType.allCases
    var orderedFaces: [BlockFace] {
        FaceType.allCases.compactMap { faces[$0] }
    }
}
