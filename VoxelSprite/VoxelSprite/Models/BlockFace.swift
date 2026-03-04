//
//  BlockFace.swift
//  VoxelSprite
//
//  Die 6 Seiten eines Minecraft-Blocks.
//  Jede Seite hat mehrere Frames (für Animation).
//  Frame 0 ist die Standard-Textur, weitere Frames für Animationen.
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

/// Eine einzelne Seite des Blocks mit mehreren Frames.
struct BlockFace: Identifiable {
    let id: UUID
    let type: FaceType
    var frames: [PixelCanvas]

    // Animation settings
    var frameTime: Int = 2          // Ticks pro Frame (20 Ticks = 1 Sekunde)
    var interpolate: Bool = false   // Smooth interpolation zwischen Frames

    /// Abwärtskompatibel: Canvas des ersten Frames
    var canvas: PixelCanvas {
        get { frames.first ?? PixelCanvas(gridSize: 16) }
        set {
            if frames.isEmpty { frames = [newValue] }
            else { frames[0] = newValue }
        }
    }

    /// Hat dieser Face mehrere Frames (Animation/CTM)?
    var isAnimated: Bool { frames.count > 1 }

    /// Anzahl der Frames
    var frameCount: Int { frames.count }

    init(type: FaceType, gridSize: Int = 16) {
        self.id = UUID()
        self.type = type
        self.frames = [PixelCanvas(gridSize: gridSize)]
    }

    init(type: FaceType, canvas: PixelCanvas) {
        self.id = UUID()
        self.type = type
        self.frames = [canvas]
    }
}
