//
//  EntityProject.swift
//  VoxelSprite
//
//  Datenmodell für Minecraft-Entity-Texturen (Mobs).
//  Unterstützt verschiedene Mob-Typen mit vordefinierten UV-Mappings.
//  Jede Entity hat benannte Körperteile mit Box-UV-Layout.
//

import SwiftUI

// MARK: - Entity Type

/// Minecraft-Mob-Typen mit vordefinierten Textur-Layouts.
enum EntityType: String, CaseIterable, Identifiable, Codable {
    case creeper   = "Creeper"
    case pig       = "Pig"
    case cow       = "Cow"
    case chicken   = "Chicken"
    case spider    = "Spider"
    case enderman  = "Enderman"
    case skeleton  = "Skeleton"

    var id: String { rawValue }

    /// Textur-Dimensionen
    var textureWidth: Int {
        switch self {
        case .creeper, .enderman, .skeleton: return 64
        case .pig, .cow, .chicken, .spider:  return 64
        }
    }

    var textureHeight: Int {
        switch self {
        case .creeper, .enderman, .skeleton: return 64
        case .pig, .cow, .chicken, .spider:  return 32
        }
    }

    /// Icon für UI
    var iconName: String {
        switch self {
        case .creeper:  return "bolt.fill"
        case .pig:      return "hare"
        case .cow:      return "pawprint"
        case .chicken:  return "bird"
        case .spider:   return "ant"
        case .enderman: return "figure.stand"
        case .skeleton: return "figure.walk"
        }
    }

    /// Körperteile mit UV-Mapping
    var bodyParts: [EntityBodyPart] {
        switch self {
        case .creeper:  return EntityUVMap.creeperParts
        case .pig:      return EntityUVMap.pigParts
        case .cow:      return EntityUVMap.cowParts
        case .chicken:  return EntityUVMap.chickenParts
        case .spider:   return EntityUVMap.spiderParts
        case .enderman: return EntityUVMap.endermanParts
        case .skeleton: return EntityUVMap.skeletonParts
        }
    }
}

// MARK: - Entity Body Part

/// Ein Körperteil eines Entity-Mobs mit UV-Mapping-Informationen.
struct EntityBodyPart: Identifiable {
    let id: String
    let name: String

    /// UV-Ursprung (oben-links des aufgeklappten Box-Bereichs)
    let originX: Int
    let originY: Int

    /// Box-Dimensionen: Breite, Höhe, Tiefe
    let boxW: Int
    let boxH: Int
    let boxD: Int

    /// UV-Region für ein bestimmtes Face
    func region(for face: SkinFace) -> SkinUVRegion {
        let ox = originX
        let oy = originY
        let w = boxW
        let h = boxH
        let d = boxD

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

// MARK: - Entity UV Maps

/// Vordefinierte UV-Mappings für verschiedene Minecraft-Mobs.
struct EntityUVMap {

    // MARK: - Creeper (64×64)

    static let creeperParts: [EntityBodyPart] = [
        EntityBodyPart(id: "head",      name: "Kopf",         originX: 0,  originY: 0,  boxW: 8, boxH: 8,  boxD: 8),
        EntityBodyPart(id: "body",      name: "Körper",       originX: 16, originY: 16, boxW: 4, boxH: 12, boxD: 8),
        EntityBodyPart(id: "leg_fr",    name: "Bein VR",      originX: 0,  originY: 16, boxW: 4, boxH: 6,  boxD: 4),
        EntityBodyPart(id: "leg_fl",    name: "Bein VL",      originX: 0,  originY: 32, boxW: 4, boxH: 6,  boxD: 4),
        EntityBodyPart(id: "leg_br",    name: "Bein HR",      originX: 0,  originY: 48, boxW: 4, boxH: 6,  boxD: 4),
        EntityBodyPart(id: "leg_bl",    name: "Bein HL",      originX: 16, originY: 48, boxW: 4, boxH: 6,  boxD: 4),
    ]

    // MARK: - Pig (64×32)

    static let pigParts: [EntityBodyPart] = [
        EntityBodyPart(id: "head",   name: "Kopf",    originX: 0,  originY: 0,  boxW: 8, boxH: 8,  boxD: 8),
        EntityBodyPart(id: "snout",  name: "Schnauze", originX: 16, originY: 16, boxW: 4, boxH: 3,  boxD: 1),
        EntityBodyPart(id: "body",   name: "Körper",  originX: 28, originY: 8,  boxW: 8, boxH: 16, boxD: 10),
        EntityBodyPart(id: "leg_fr", name: "Bein VR", originX: 0,  originY: 16, boxW: 4, boxH: 6,  boxD: 4),
        EntityBodyPart(id: "leg_fl", name: "Bein VL", originX: 0,  originY: 16, boxW: 4, boxH: 6,  boxD: 4),
        EntityBodyPart(id: "leg_br", name: "Bein HR", originX: 0,  originY: 16, boxW: 4, boxH: 6,  boxD: 4),
        EntityBodyPart(id: "leg_bl", name: "Bein HL", originX: 0,  originY: 16, boxW: 4, boxH: 6,  boxD: 4),
    ]

    // MARK: - Cow (64×32)

    static let cowParts: [EntityBodyPart] = [
        EntityBodyPart(id: "head",   name: "Kopf",    originX: 0,  originY: 0,  boxW: 8, boxH: 8,  boxD: 8),
        EntityBodyPart(id: "horn_r", name: "Horn R",   originX: 22, originY: 0,  boxW: 1, boxH: 3,  boxD: 1),
        EntityBodyPart(id: "horn_l", name: "Horn L",   originX: 22, originY: 0,  boxW: 1, boxH: 3,  boxD: 1),
        EntityBodyPart(id: "body",   name: "Körper",  originX: 18, originY: 4,  boxW: 10, boxH: 18, boxD: 6),
        EntityBodyPart(id: "leg_fr", name: "Bein VR", originX: 0,  originY: 16, boxW: 4, boxH: 12, boxD: 4),
        EntityBodyPart(id: "leg_fl", name: "Bein VL", originX: 0,  originY: 16, boxW: 4, boxH: 12, boxD: 4),
        EntityBodyPart(id: "leg_br", name: "Bein HR", originX: 0,  originY: 16, boxW: 4, boxH: 12, boxD: 4),
        EntityBodyPart(id: "leg_bl", name: "Bein HL", originX: 0,  originY: 16, boxW: 4, boxH: 12, boxD: 4),
    ]

    // MARK: - Chicken (64×32)

    static let chickenParts: [EntityBodyPart] = [
        EntityBodyPart(id: "head",  name: "Kopf",     originX: 0,  originY: 0,  boxW: 4, boxH: 6, boxD: 3),
        EntityBodyPart(id: "beak",  name: "Schnabel", originX: 14, originY: 0,  boxW: 4, boxH: 2, boxD: 2),
        EntityBodyPart(id: "wattle", name: "Kehllappen", originX: 14, originY: 4, boxW: 2, boxH: 2, boxD: 2),
        EntityBodyPart(id: "body",  name: "Körper",   originX: 0,  originY: 9,  boxW: 6, boxH: 8, boxD: 6),
        EntityBodyPart(id: "leg_r", name: "Bein R",   originX: 26, originY: 0,  boxW: 3, boxH: 5, boxD: 3),
        EntityBodyPart(id: "leg_l", name: "Bein L",   originX: 26, originY: 0,  boxW: 3, boxH: 5, boxD: 3),
        EntityBodyPart(id: "wing_r", name: "Flügel R", originX: 24, originY: 13, boxW: 1, boxH: 4, boxD: 6),
        EntityBodyPart(id: "wing_l", name: "Flügel L", originX: 24, originY: 13, boxW: 1, boxH: 4, boxD: 6),
    ]

    // MARK: - Spider (64×32)

    static let spiderParts: [EntityBodyPart] = [
        EntityBodyPart(id: "head",     name: "Kopf",      originX: 32, originY: 4,  boxW: 8, boxH: 8,  boxD: 8),
        EntityBodyPart(id: "abdomen",  name: "Abdomen",   originX: 0,  originY: 0,  boxW: 12, boxH: 8, boxD: 10),
        EntityBodyPart(id: "thorax",   name: "Thorax",    originX: 0,  originY: 12, boxW: 6, boxH: 6,  boxD: 6),
    ]

    // MARK: - Enderman (64×64)

    static let endermanParts: [EntityBodyPart] = [
        EntityBodyPart(id: "head",      name: "Kopf",      originX: 0,  originY: 0,  boxW: 8, boxH: 8,  boxD: 8),
        EntityBodyPart(id: "body",      name: "Körper",    originX: 32, originY: 16, boxW: 4, boxH: 30, boxD: 8),
        EntityBodyPart(id: "right_arm", name: "R. Arm",    originX: 56, originY: 0,  boxW: 2, boxH: 30, boxD: 2),
        EntityBodyPart(id: "left_arm",  name: "L. Arm",    originX: 56, originY: 0,  boxW: 2, boxH: 30, boxD: 2),
        EntityBodyPart(id: "right_leg", name: "R. Bein",   originX: 56, originY: 0,  boxW: 2, boxH: 30, boxD: 2),
        EntityBodyPart(id: "left_leg",  name: "L. Bein",   originX: 56, originY: 0,  boxW: 2, boxH: 30, boxD: 2),
    ]

    // MARK: - Skeleton (64×64)

    static let skeletonParts: [EntityBodyPart] = [
        EntityBodyPart(id: "head",      name: "Kopf",      originX: 0,  originY: 0,  boxW: 8, boxH: 8,  boxD: 8),
        EntityBodyPart(id: "body",      name: "Körper",    originX: 16, originY: 16, boxW: 8, boxH: 12, boxD: 4),
        EntityBodyPart(id: "right_arm", name: "R. Arm",    originX: 40, originY: 16, boxW: 2, boxH: 12, boxD: 2),
        EntityBodyPart(id: "left_arm",  name: "L. Arm",    originX: 40, originY: 16, boxW: 2, boxH: 12, boxD: 2),
        EntityBodyPart(id: "right_leg", name: "R. Bein",   originX: 0,  originY: 16, boxW: 2, boxH: 12, boxD: 2),
        EntityBodyPart(id: "left_leg",  name: "L. Bein",   originX: 0,  originY: 16, boxW: 2, boxH: 12, boxD: 2),
    ]
}

// MARK: - Entity Project

struct EntityProject {

    /// Name des Entity-Projekts — für Dateiexport
    var name: String

    /// Minecraft Namespace
    var namespace: String

    /// Entity-Typ (bestimmt UV-Layout und Textur-Größe)
    var entityType: EntityType

    /// Texture Canvas (volle Textur-Atlas-Größe)
    var texture: PixelCanvas

    // MARK: - Init

    init(
        name: String = "custom_entity",
        namespace: String = "minecraft",
        entityType: EntityType = .creeper
    ) {
        self.name = name
        self.namespace = namespace
        self.entityType = entityType
        self.texture = PixelCanvas(width: entityType.textureWidth, height: entityType.textureHeight)
    }

    // MARK: - Entity-Typ wechseln

    /// Wechselt den Entity-Typ und erstellt ein neues Canvas
    mutating func changeType(to type: EntityType) {
        entityType = type
        texture = PixelCanvas(width: type.textureWidth, height: type.textureHeight)
    }

    // MARK: - Region-Extraktion

    /// Extrahiert die UV-Region eines Körperteils/Face als separates Canvas
    func extractRegion(bodyPart: EntityBodyPart, face: SkinFace) -> PixelCanvas {
        let region = bodyPart.region(for: face)
        var canvas = PixelCanvas(width: region.width, height: region.height)
        for y in 0..<region.height {
            for x in 0..<region.width {
                let srcX = region.x + x
                let srcY = region.y + y
                if srcX < texture.width && srcY < texture.height {
                    canvas.setPixel(at: x, y: y, color: texture.pixel(at: srcX, y: srcY))
                }
            }
        }
        return canvas
    }

    /// Schreibt ein bearbeitetes Canvas zurück in die Textur
    mutating func writeRegion(bodyPart: EntityBodyPart, face: SkinFace, canvas: PixelCanvas) {
        let region = bodyPart.region(for: face)
        for y in 0..<region.height {
            for x in 0..<region.width {
                let dstX = region.x + x
                let dstY = region.y + y
                if dstX < texture.width && dstY < texture.height {
                    let color = canvas.pixel(at: x, y: y)
                    texture.setPixel(at: dstX, y: dstY, color: color)
                }
            }
        }
    }
}
