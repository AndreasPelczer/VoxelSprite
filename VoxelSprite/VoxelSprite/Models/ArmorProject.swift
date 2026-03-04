//
//  ArmorProject.swift
//  VoxelSprite
//
//  Datenmodell für Minecraft-Rüstungstexturen (Armor).
//  Zwei Texture-Layer: Layer 1 (Helm, Brustplatte, Stiefel) und Layer 2 (Beinschutz).
//  Beide Layer sind 64×32 Pixel mit Box-UV-Layout.
//

import SwiftUI

// MARK: - Armor Piece

/// Rüstungsteile in Minecraft.
enum ArmorPiece: String, CaseIterable, Identifiable {
    case helmet      = "Helm"
    case chestplate  = "Brustplatte"
    case rightArm    = "R. Arm"
    case leftArm     = "L. Arm"
    case leggingsBody = "Beinschutz"
    case rightLeg    = "R. Bein"
    case leftLeg     = "L. Bein"
    case rightBoot   = "R. Stiefel"
    case leftBoot    = "L. Stiefel"

    var id: String { rawValue }

    /// Zu welchem Armor-Layer gehört dieses Teil?
    var armorLayer: ArmorLayer {
        switch self {
        case .helmet, .chestplate, .rightArm, .leftArm, .rightBoot, .leftBoot:
            return .layer1
        case .leggingsBody, .rightLeg, .leftLeg:
            return .layer2
        }
    }

    /// Icon für UI
    var iconName: String {
        switch self {
        case .helmet:       return "crown"
        case .chestplate:   return "tshirt"
        case .rightArm:     return "hand.raised"
        case .leftArm:      return "hand.raised.fill"
        case .leggingsBody: return "figure.stand"
        case .rightLeg:     return "figure.walk"
        case .leftLeg:      return "figure.walk.motion"
        case .rightBoot:    return "square.bottomhalf.filled"
        case .leftBoot:     return "square.bottomhalf.filled"
        }
    }

    /// Box-Dimensionen (Breite, Höhe, Tiefe) in Pixeln
    var dimensions: (w: Int, h: Int, d: Int) {
        switch self {
        case .helmet:                       return (8, 8, 8)
        case .chestplate:                   return (8, 12, 4)
        case .rightArm, .leftArm:           return (4, 12, 4)
        case .leggingsBody:                 return (8, 12, 4)
        case .rightLeg, .leftLeg:           return (4, 12, 4)
        case .rightBoot, .leftBoot:         return (4, 12, 4)
        }
    }
}

// MARK: - Armor Layer

/// Die zwei Textur-Layer für Minecraft-Rüstungen.
enum ArmorLayer: String, CaseIterable, Identifiable {
    case layer1 = "Layer 1"
    case layer2 = "Layer 2"

    var id: String { rawValue }

    /// Layer 1: Helm, Brustplatte, Stiefel | Layer 2: Beinschutz
    var description: String {
        switch self {
        case .layer1: return "Helm · Brustplatte · Arme · Stiefel"
        case .layer2: return "Beinschutz"
        }
    }

    /// Icon
    var iconName: String {
        switch self {
        case .layer1: return "1.square"
        case .layer2: return "2.square"
        }
    }

    /// Welche Pieces gehören zu diesem Layer?
    var pieces: [ArmorPiece] {
        switch self {
        case .layer1: return [.helmet, .chestplate, .rightArm, .leftArm, .rightBoot, .leftBoot]
        case .layer2: return [.leggingsBody, .rightLeg, .leftLeg]
        }
    }
}

// MARK: - Armor UV Map

/// UV-Mapping für Minecraft-Rüstungstexturen.
/// Folgt dem gleichen Box-Entfaltungs-Layout wie Skins.
struct ArmorUVMap {

    /// UV-Ursprünge für Layer 1 (64×32)
    static let layer1Origins: [ArmorPiece: (x: Int, y: Int)] = [
        .helmet:     (0, 0),
        .chestplate: (16, 16),
        .rightArm:   (40, 16),
        .leftArm:    (40, 16),  // gespiegelt
        .rightBoot:  (0, 16),
        .leftBoot:   (0, 16),   // gespiegelt
    ]

    /// UV-Ursprünge für Layer 2 (64×32)
    static let layer2Origins: [ArmorPiece: (x: Int, y: Int)] = [
        .leggingsBody: (16, 0),
        .rightLeg:     (0, 0),
        .leftLeg:      (0, 16),
    ]

    /// UV-Region für ein bestimmtes Rüstungsteil und Face
    static func region(piece: ArmorPiece, face: SkinFace) -> SkinUVRegion {
        let (w, h, d) = piece.dimensions
        let origins = piece.armorLayer == .layer1 ? layer1Origins : layer2Origins

        guard let origin = origins[piece] else {
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

// MARK: - Armor Material

/// Rüstungsmaterial bestimmt die Textur-Farbe.
enum ArmorMaterial: String, CaseIterable, Identifiable, Codable {
    case leather   = "Leder"
    case chainmail = "Kette"
    case iron      = "Eisen"
    case gold      = "Gold"
    case diamond   = "Diamant"
    case netherite = "Netherit"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .leather:   return "leaf"
        case .chainmail: return "link"
        case .iron:      return "shield"
        case .gold:      return "star"
        case .diamond:   return "diamond"
        case .netherite: return "flame"
        }
    }
}

// MARK: - Armor Project

struct ArmorProject {

    /// Name der Rüstung — für Dateiexport
    var name: String

    /// Minecraft Namespace
    var namespace: String

    /// Material (für Textur-Zuordnung)
    var material: ArmorMaterial

    /// Layer 1: Helm, Brustplatte, Arme, Stiefel (64×32)
    var layer1: PixelCanvas

    /// Layer 2: Beinschutz (64×32)
    var layer2: PixelCanvas

    // MARK: - Init

    init(
        name: String = "custom_armor",
        namespace: String = "minecraft",
        material: ArmorMaterial = .iron
    ) {
        self.name = name
        self.namespace = namespace
        self.material = material
        self.layer1 = PixelCanvas(width: 64, height: 32)
        self.layer2 = PixelCanvas(width: 64, height: 32)
    }

    // MARK: - Canvas für Layer

    func canvas(for layer: ArmorLayer) -> PixelCanvas {
        switch layer {
        case .layer1: return layer1
        case .layer2: return layer2
        }
    }

    // MARK: - Region-Extraktion

    /// Extrahiert die UV-Region eines Rüstungsteils als separates Canvas
    func extractRegion(piece: ArmorPiece, face: SkinFace) -> PixelCanvas {
        let region = ArmorUVMap.region(piece: piece, face: face)
        let source = piece.armorLayer == .layer1 ? layer1 : layer2
        var canvas = PixelCanvas(width: region.width, height: region.height)
        for y in 0..<region.height {
            for x in 0..<region.width {
                let srcX = region.x + x
                let srcY = region.y + y
                if srcX < source.width && srcY < source.height {
                    canvas.setPixel(at: x, y: y, color: source.pixel(at: srcX, y: srcY))
                }
            }
        }
        return canvas
    }

    /// Schreibt ein bearbeitetes Canvas zurück in den Layer
    mutating func writeRegion(piece: ArmorPiece, face: SkinFace, canvas: PixelCanvas) {
        let region = ArmorUVMap.region(piece: piece, face: face)
        for y in 0..<region.height {
            for x in 0..<region.width {
                let dstX = region.x + x
                let dstY = region.y + y
                let color = canvas.pixel(at: x, y: y)
                if piece.armorLayer == .layer1 {
                    if dstX < layer1.width && dstY < layer1.height {
                        layer1.setPixel(at: dstX, y: dstY, color: color)
                    }
                } else {
                    if dstX < layer2.width && dstY < layer2.height {
                        layer2.setPixel(at: dstX, y: dstY, color: color)
                    }
                }
            }
        }
    }
}
