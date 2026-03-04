//
//  PaintingProject.swift
//  VoxelSprite
//
//  Datenmodell für Minecraft-Gemälde (Paintings).
//  Unterstützt alle Standard-Gemäldegrößen von 1×1 bis 4×4 Blöcke.
//  Export als PNG + Datapack-Registrierung (painting_variant, 1.19+).
//

import SwiftUI

// MARK: - Painting Size

/// Minecraft-Gemäldegrößen in Blöcken (1 Block = 16 Pixel).
enum PaintingSize: String, CaseIterable, Identifiable, Codable {
    case s1x1 = "1×1"
    case s2x1 = "2×1"
    case s1x2 = "1×2"
    case s2x2 = "2×2"
    case s4x2 = "4×2"
    case s4x3 = "4×3"
    case s4x4 = "4×4"

    var id: String { rawValue }

    /// Breite in Blöcken
    var blocksWide: Int {
        switch self {
        case .s1x1, .s1x2:          return 1
        case .s2x1, .s2x2:          return 2
        case .s4x2, .s4x3, .s4x4:   return 4
        }
    }

    /// Höhe in Blöcken
    var blocksTall: Int {
        switch self {
        case .s1x1, .s2x1:          return 1
        case .s1x2, .s2x2, .s4x2:   return 2
        case .s4x3:                  return 3
        case .s4x4:                  return 4
        }
    }

    /// Pixel-Breite
    var pixelWidth: Int { blocksWide * 16 }

    /// Pixel-Höhe
    var pixelHeight: Int { blocksTall * 16 }

    /// Icon
    var iconName: String {
        switch self {
        case .s1x1: return "square"
        case .s2x1: return "rectangle"
        case .s1x2: return "rectangle.portrait"
        case .s2x2: return "square.fill"
        case .s4x2: return "rectangle.fill"
        case .s4x3: return "rectangle.fill"
        case .s4x4: return "square.dashed"
        }
    }

    /// Beschreibung
    var description: String {
        "\(pixelWidth)×\(pixelHeight) px"
    }
}

// MARK: - Painting Project

struct PaintingProject {

    /// Name des Gemäldes — für Dateiexport
    var name: String

    /// Größe des Gemäldes
    var size: PaintingSize

    /// Minecraft Namespace
    var namespace: String

    /// Canvas
    var canvas: PixelCanvas

    // MARK: - Init

    init(
        name: String = "custom_painting",
        size: PaintingSize = .s2x2,
        namespace: String = "minecraft"
    ) {
        self.name = name
        self.size = size
        self.namespace = namespace
        self.canvas = PixelCanvas(width: size.pixelWidth, height: size.pixelHeight)
    }

    // MARK: - Größe ändern

    /// Ändert die Größe und erstellt ein neues Canvas
    mutating func resize(to newSize: PaintingSize) {
        size = newSize
        canvas = PixelCanvas(width: newSize.pixelWidth, height: newSize.pixelHeight)
    }
}
