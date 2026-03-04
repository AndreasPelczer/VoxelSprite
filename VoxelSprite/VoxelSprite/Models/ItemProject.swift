//
//  ItemProject.swift
//  VoxelSprite
//
//  Datenmodell für Minecraft Items.
//  Ein Item hat eine oder mehrere Textur-Layer (layer0, layer1, ...),
//  einen Display-Typ und Metadaten für den Resourcepack-Export.
//

import SwiftUI

// MARK: - Item Display Type

/// Bestimmt wie das Item in Minecraft angezeigt wird.
enum ItemDisplayType: String, CaseIterable, Identifiable, Codable {
    case generated = "Generated"     // Flaches Sprite (Äpfel, Diamanten, etc.)
    case handheld  = "Handheld"      // Tool-Style (Schwert, Spitzhacke)

    var id: String { rawValue }

    /// Minecraft Parent-Modell
    var parent: String {
        switch self {
        case .generated: return "minecraft:item/generated"
        case .handheld:  return "minecraft:item/handheld"
        }
    }

    var iconName: String {
        switch self {
        case .generated: return "sparkle"
        case .handheld:  return "hammer"
        }
    }

    var description: String {
        switch self {
        case .generated: return "Flaches Sprite (Items, Nahrung)"
        case .handheld:  return "Tool-Stil (Schwert, Axt)"
        }
    }
}

// MARK: - Item Project

/// Ein komplettes Item-Projekt.
/// Items bestehen aus einer oder mehreren Textur-Layern.
struct ItemProject {

    /// Name des Items — für Dateiexport
    var name: String

    /// Display-Typ bestimmt das Parent-Modell
    var displayType: ItemDisplayType

    /// Minecraft Namespace
    var namespace: String

    /// Ziel-Version
    var targetVersion: BlockProject.TargetVersion

    /// Textur-Layer (layer0, layer1, ...)
    /// layer0 = Basis, layer1+ = Overlays (z.B. Trank-Flüssigkeit)
    var layers: [PixelCanvas]

    /// Rastergröße
    var gridSize: Int

    // MARK: - Init

    init(
        name: String = "custom_item",
        gridSize: Int = 16,
        displayType: ItemDisplayType = .generated,
        namespace: String = "minecraft",
        targetVersion: BlockProject.TargetVersion = .java
    ) {
        self.name = name
        self.gridSize = gridSize
        self.displayType = displayType
        self.namespace = namespace
        self.targetVersion = targetVersion
        self.layers = [PixelCanvas(gridSize: gridSize)]
    }

    /// Anzahl der Layer
    var layerCount: Int { layers.count }

    /// Hat mehrere Layer?
    var isMultiLayer: Bool { layers.count > 1 }

    // MARK: - Compositing

    /// Kombiniert alle Layer zu einem einzigen Canvas.
    /// Spätere Layer überdecken frühere (wie in Minecraft).
    func composited() -> PixelCanvas {
        guard !layers.isEmpty else { return PixelCanvas(gridSize: gridSize) }

        var result = PixelCanvas(gridSize: gridSize)
        for layer in layers {
            for y in 0..<gridSize {
                for x in 0..<gridSize {
                    if let color = layer.pixel(at: x, y: y) {
                        result.setPixel(at: x, y: y, color: color)
                    }
                }
            }
        }
        return result
    }

    // MARK: - Layer-Namen

    /// Gibt den Textur-Dateinamen für einen Layer zurück
    func textureName(for layerIndex: Int) -> String {
        if layers.count == 1 {
            return name
        } else {
            return layerIndex == 0 ? name : "\(name)_layer\(layerIndex)"
        }
    }
}
