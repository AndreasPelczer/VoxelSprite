//
//  SkinProject.swift
//  VoxelSprite
//
//  Datenmodell für Minecraft Andy-Skins.
//  64×64 Pixel Texture Atlas mit UV-Mapping für Körperteile.
//  Zwei Layer: Base + Overlay (Helm, Jacke, etc.)
//

import SwiftUI

// MARK: - Skin Body Parts

enum SkinBodyPart: String, CaseIterable, Identifiable {
    case head     = "Kopf"
    case body     = "Körper"
    case rightArm = "R. Arm"
    case leftArm  = "L. Arm"
    case rightLeg = "R. Bein"
    case leftLeg  = "L. Bein"

    var id: String { rawValue }

    /// Box-Dimensionen: (Breite, Höhe, Tiefe) in Pixeln
    var dimensions: (w: Int, h: Int, d: Int) {
        switch self {
        case .head:                  return (8, 8, 8)
        case .body:                  return (8, 12, 4)
        case .rightArm, .leftArm:   return (4, 12, 4)
        case .rightLeg, .leftLeg:   return (4, 12, 4)
        }
    }

    var iconName: String {
        switch self {
        case .head:     return "person.crop.circle"
        case .body:     return "figure.stand"
        case .rightArm: return "hand.raised"
        case .leftArm:  return "hand.raised.fill"
        case .rightLeg: return "figure.walk"
        case .leftLeg:  return "figure.walk.motion"
        }
    }
}

// MARK: - Skin Face

enum SkinFace: String, CaseIterable, Identifiable {
    case front  = "Front"
    case back   = "Back"
    case top    = "Top"
    case bottom = "Bottom"
    case right  = "Right"
    case left   = "Left"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .front:  return "F"
        case .back:   return "B"
        case .top:    return "T"
        case .bottom: return "Bo"
        case .right:  return "R"
        case .left:   return "L"
        }
    }
}

// MARK: - Skin Layer

enum SkinLayer: String, CaseIterable, Identifiable {
    case base    = "Base"
    case overlay = "Overlay"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .base:    return "square"
        case .overlay: return "square.on.square"
        }
    }
}

// MARK: - UV Region

struct SkinUVRegion {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

// MARK: - UV Map (Minecraft Skin Standard 64×64)

/// UV-Mapping basiert auf dem aufgeklappten Box-Layout:
///
///          [top: w×d]    [bottom: w×d]
/// [right: d×h] [front: w×h] [left: d×h] [back: w×h]
///
struct SkinUVMap {

    /// UV-Ursprung (oben-links des aufgeklappten Box-Bereichs)
    static let origins: [SkinLayer: [SkinBodyPart: (x: Int, y: Int)]] = [
        .base: [
            .head:     (0, 0),
            .body:     (16, 16),
            .rightArm: (40, 16),
            .rightLeg: (0, 16),
            .leftLeg:  (16, 48),
            .leftArm:  (32, 48),
        ],
        .overlay: [
            .head:     (32, 0),
            .body:     (16, 32),
            .rightArm: (40, 32),
            .rightLeg: (0, 32),
            .leftLeg:  (0, 48),
            .leftArm:  (48, 48),
        ]
    ]

    /// UV-Region für ein bestimmtes Face eines Körperteils
    static func region(bodyPart: SkinBodyPart, face: SkinFace, layer: SkinLayer) -> SkinUVRegion {
        let (w, h, d) = bodyPart.dimensions
        guard let origin = origins[layer]?[bodyPart] else {
            return SkinUVRegion(x: 0, y: 0, width: w, height: h)
        }

        let ox = origin.x
        let oy = origin.y

        switch face {
        case .top:    return SkinUVRegion(x: ox + d,         y: oy,     width: w, height: d)
        case .bottom: return SkinUVRegion(x: ox + d + w,     y: oy,     width: w, height: d)
        case .right:  return SkinUVRegion(x: ox,             y: oy + d, width: d, height: h)
        case .front:  return SkinUVRegion(x: ox + d,         y: oy + d, width: w, height: h)
        case .left:   return SkinUVRegion(x: ox + d + w,     y: oy + d, width: d, height: h)
        case .back:   return SkinUVRegion(x: ox + d + w + d, y: oy + d, width: w, height: h)
        }
    }
}

// MARK: - Skin Project

struct SkinProject {

    var name: String

    /// Base Layer: Grundtextur (64×64)
    var baseLayer: PixelCanvas

    /// Overlay Layer: Helm, Jacke, etc. (64×64)
    var overlayLayer: PixelCanvas

    init(name: String = "andy") {
        self.name = name
        self.baseLayer = PixelCanvas(width: 64, height: 64)
        self.overlayLayer = PixelCanvas(width: 64, height: 64)
    }

    // MARK: - Region-Extraktion

    /// Extrahiert die UV-Region als separates Canvas zum Bearbeiten
    func extractRegion(bodyPart: SkinBodyPart, face: SkinFace, layer: SkinLayer) -> PixelCanvas {
        let region = SkinUVMap.region(bodyPart: bodyPart, face: face, layer: layer)
        let source = layer == .base ? baseLayer : overlayLayer
        var canvas = PixelCanvas(width: region.width, height: region.height)
        for y in 0..<region.height {
            for x in 0..<region.width {
                canvas.setPixel(at: x, y: y, color: source.pixel(at: region.x + x, y: region.y + y))
            }
        }
        return canvas
    }

    /// Schreibt ein bearbeitetes Canvas zurück in den Skin-Layer
    mutating func writeRegion(bodyPart: SkinBodyPart, face: SkinFace, layer: SkinLayer, canvas: PixelCanvas) {
        let region = SkinUVMap.region(bodyPart: bodyPart, face: face, layer: layer)
        for y in 0..<region.height {
            for x in 0..<region.width {
                let color = canvas.pixel(at: x, y: y)
                if layer == .base {
                    baseLayer.setPixel(at: region.x + x, y: region.y + y, color: color)
                } else {
                    overlayLayer.setPixel(at: region.x + x, y: region.y + y, color: color)
                }
            }
        }
    }

    // MARK: - Compositing

    /// Kombiniert Base + Overlay zu einem finalen 64×64 Canvas
    func composited() -> PixelCanvas {
        var result = baseLayer
        for y in 0..<64 {
            for x in 0..<64 {
                if let overlayColor = overlayLayer.pixel(at: x, y: y) {
                    result.setPixel(at: x, y: y, color: overlayColor)
                }
            }
        }
        return result
    }
}
