//
//  BlockFace.swift
//  VoxelSprite
//
//  Die 6 Seiten eines Minecraft-Blocks.
//  Jede Seite hat ein eigenes 16×16 PixelCanvas.
//

import SwiftUI

// MARK: - Face Type

/// Die 6 Seiten eines Würfels.
/// Reihenfolge entspricht der Minecraft-Konvention.
enum FaceType: String, CaseIterable, Identifiable, Codable {
    case top    = "Top"
    case bottom = "Bottom"
    case north  = "North"
    case south  = "South"
    case east   = "East"
    case west   = "West"

    var id: String { rawValue }

    /// SF Symbol für die UI
    var iconName: String {
        switch self {
        case .top:    return "arrow.up.square"
        case .bottom: return "arrow.down.square"
        case .north:  return "arrow.up.circle"
        case .south:  return "arrow.down.circle"
        case .east:   return "arrow.right.circle"
        case .west:   return "arrow.left.circle"
        }
    }

    /// Kurzbezeichnung für kompakte Darstellung
    var shortLabel: String {
        switch self {
        case .top:    return "T"
        case .bottom: return "B"
        case .north:  return "N"
        case .south:  return "S"
        case .east:   return "E"
        case .west:   return "W"
        }
    }

    /// Tastenkürzel (1–6) für schnellen Wechsel
    var keyboardShortcut: String {
        switch self {
        case .top:    return "1"
        case .bottom: return "2"
        case .north:  return "3"
        case .south:  return "4"
        case .east:   return "5"
        case .west:   return "6"
        }
    }
}

// MARK: - Block Face

/// Eine einzelne Seite des Blocks mit eigenem Canvas.
struct BlockFace: Identifiable {
    let id: UUID
    let type: FaceType
    var canvas: PixelCanvas

    init(type: FaceType, gridSize: Int = 16) {
        self.id = UUID()
        self.type = type
        self.canvas = PixelCanvas(gridSize: gridSize)
    }

    init(type: FaceType, canvas: PixelCanvas) {
        self.id = UUID()
        self.type = type
        self.canvas = canvas
    }
}
