//
//  ExampleData.swift
//  VoxelSprite
//
//  Befüllt alle 7 Editoren mit Beispieldaten für App Store Screenshots.
//  Wird beim App-Start einmalig aufgerufen.
//

import SwiftUI

// MARK: - Minecraft-Farben

private extension Color {
    // Grasblock
    static let grassTop    = Color(red: 0.42, green: 0.65, blue: 0.31)
    static let grassTopDk  = Color(red: 0.35, green: 0.55, blue: 0.25)
    static let grassSide   = Color(red: 0.55, green: 0.37, blue: 0.24)
    static let grassSideDk = Color(red: 0.45, green: 0.30, blue: 0.18)
    static let dirtBase    = Color(red: 0.53, green: 0.36, blue: 0.22)
    static let dirtDark    = Color(red: 0.43, green: 0.28, blue: 0.16)
    static let dirtLight   = Color(red: 0.60, green: 0.42, blue: 0.28)

    // Schwert
    static let diamondBlade  = Color(red: 0.40, green: 0.89, blue: 0.87)
    static let diamondEdge   = Color(red: 0.25, green: 0.72, blue: 0.70)
    static let diamondShine  = Color(red: 0.65, green: 0.95, blue: 0.94)
    static let stickBrown    = Color(red: 0.60, green: 0.40, blue: 0.20)
    static let stickDark     = Color(red: 0.48, green: 0.32, blue: 0.16)

    // Creeper
    static let creeperGreen  = Color(red: 0.30, green: 0.60, blue: 0.18)
    static let creeperDark   = Color(red: 0.22, green: 0.48, blue: 0.12)
    static let creeperLight  = Color(red: 0.38, green: 0.70, blue: 0.25)
    static let creeperBlack  = Color(red: 0.10, green: 0.10, blue: 0.08)

    // Skin (Andy)
    static let skinTone      = Color(red: 0.82, green: 0.64, blue: 0.48)
    static let skinDark      = Color(red: 0.68, green: 0.50, blue: 0.35)
    static let hairBrown     = Color(red: 0.35, green: 0.22, blue: 0.12)
    static let shirtBlue     = Color(red: 0.20, green: 0.40, blue: 0.75)
    static let shirtBlueDk   = Color(red: 0.15, green: 0.30, blue: 0.60)
    static let pantsBrown    = Color(red: 0.30, green: 0.22, blue: 0.55)
    static let pantsDark     = Color(red: 0.22, green: 0.16, blue: 0.42)
    static let shoeDark      = Color(red: 0.25, green: 0.20, blue: 0.18)

    // Rüstung (Diamond)
    static let armorDiamond  = Color(red: 0.40, green: 0.89, blue: 0.87)
    static let armorDiaDark  = Color(red: 0.28, green: 0.68, blue: 0.66)
    static let armorDiaLight = Color(red: 0.55, green: 0.95, blue: 0.93)

    // Painting
    static let skyBlue       = Color(red: 0.53, green: 0.75, blue: 0.92)
    static let cloudWhite    = Color(red: 0.95, green: 0.96, blue: 0.98)
    static let mountainGrey  = Color(red: 0.45, green: 0.50, blue: 0.52)
    static let mountainSnow  = Color(red: 0.88, green: 0.90, blue: 0.92)
    static let fieldGreen    = Color(red: 0.35, green: 0.58, blue: 0.28)
    static let fieldLight    = Color(red: 0.45, green: 0.68, blue: 0.35)
    static let sunYellow     = Color(red: 1.00, green: 0.90, blue: 0.30)
}

// MARK: - Example Data

struct ExampleData {

    // MARK: - 1. Block Editor: Grasblock

    static func fillBlock(_ blockVM: BlockViewModel) {
        blockVM.project.name = "grass_block"

        // Top: Grüne Oberfläche mit Variationen
        fillFace(&blockVM.project, face: .top) { x, y in
            let noise = (x &+ y * 3) % 7
            if noise < 2 { return .grassTopDk }
            if noise == 6 { return .dirtLight }
            return .grassTop
        }

        // Bottom: Erde
        fillFace(&blockVM.project, face: .bottom) { x, y in
            let noise = (x * 3 &+ y * 7) % 5
            if noise < 1 { return .dirtDark }
            if noise == 4 { return .dirtLight }
            return .dirtBase
        }

        // Seiten: Gras oben, Erde unten
        for side: FaceType in [.north, .south, .east, .west] {
            fillFace(&blockVM.project, face: side) { x, y in
                if y < 3 {
                    // Gras-Streifen oben
                    let noise = (x &+ y * 5) % 6
                    if y == 0 { return noise < 3 ? .grassTop : .grassTopDk }
                    if y == 1 { return noise < 2 ? .grassTop : (noise < 4 ? .grassSide : .grassSideDk) }
                    return noise < 3 ? .grassSide : .grassSideDk
                } else {
                    // Erde
                    let noise = (x * 3 &+ y * 7) % 5
                    if noise < 1 { return .dirtDark }
                    if noise == 4 { return .dirtLight }
                    return .dirtBase
                }
            }
        }
    }

    // MARK: - 2. Item Editor: Diamantschwert

    static func fillItem(_ itemVM: ItemViewModel) {
        itemVM.project.name = "diamond_sword"

        // 16×16 Diamant-Schwert (diagonal, von unten-links nach oben-rechts)
        let sword: [(Int, Int, Color)] = [
            // Klinge (diagonal von oben-rechts nach Mitte)
            (14, 1, .diamondShine), (13, 2, .diamondBlade), (14, 2, .diamondEdge),
            (12, 3, .diamondShine), (13, 3, .diamondBlade), (14, 3, .diamondEdge),
            (11, 4, .diamondShine), (12, 4, .diamondBlade), (13, 4, .diamondEdge),
            (10, 5, .diamondShine), (11, 5, .diamondBlade), (12, 5, .diamondEdge),
            (9, 6, .diamondShine), (10, 6, .diamondBlade), (11, 6, .diamondEdge),
            (8, 7, .diamondShine), (9, 7, .diamondBlade), (10, 7, .diamondEdge),
            (7, 8, .diamondShine), (8, 8, .diamondBlade), (9, 8, .diamondEdge),
            // Griff-Übergang
            (6, 9, .diamondEdge), (7, 9, .stickBrown),
            // Parierstange
            (5, 10, .stickDark), (6, 10, .stickBrown), (7, 10, .stickDark),
            // Griff
            (5, 11, .stickBrown), (4, 12, .stickBrown), (4, 11, .stickDark),
            (3, 13, .stickBrown), (3, 12, .stickDark),
            (2, 14, .stickBrown), (2, 13, .stickDark),
        ]

        for (x, y, color) in sword {
            itemVM.project.layers[0].setPixel(at: x, y: y, color: color)
        }
    }

    // MARK: - 3. Skin Editor: Andy

    static func fillSkin(_ skinVM: SkinViewModel) {
        skinVM.project.name = "andy"

        // Head UV: base origin (0, 0), d=8, w=8, h=8
        // Front face: (8, 8) to (15, 15) — Gesicht
        fillRegion(&skinVM.project.baseLayer, x: 8, y: 8, w: 8, h: 8) { px, py in
            // Hautfarbe Basis
            if py >= 4 && py <= 5 && (px == 2 || px == 5) { return .hairBrown } // Augen
            if py == 6 && px >= 3 && px <= 4 { return .skinDark } // Mund
            return .skinTone
        }
        // Top face: (8, 0) to (15, 7) — Kopfoberseite (Haare)
        fillRegion(&skinVM.project.baseLayer, x: 8, y: 0, w: 8, h: 8) { _, _ in .hairBrown }
        // Back, Left, Right faces — Haare/Haut
        fillRegion(&skinVM.project.baseLayer, x: 24, y: 8, w: 8, h: 8) { _, _ in .hairBrown } // Back
        fillRegion(&skinVM.project.baseLayer, x: 0, y: 8, w: 8, h: 8) { _, _ in .hairBrown }  // Right
        fillRegion(&skinVM.project.baseLayer, x: 16, y: 8, w: 8, h: 8) { _, py in
            py < 4 ? .hairBrown : .skinTone
        } // Left
        // Bottom face
        fillRegion(&skinVM.project.baseLayer, x: 16, y: 0, w: 8, h: 8) { _, _ in .hairBrown }

        // Body UV: base origin (16, 16)
        // Front: (20, 20) to (27, 31)
        fillRegion(&skinVM.project.baseLayer, x: 20, y: 20, w: 8, h: 12) { _, _ in .shirtBlue }
        // Back: (32, 20) to (39, 31)
        fillRegion(&skinVM.project.baseLayer, x: 32, y: 20, w: 8, h: 12) { _, _ in .shirtBlueDk }
        // Left: (16, 20) to (19, 31)
        fillRegion(&skinVM.project.baseLayer, x: 16, y: 20, w: 4, h: 12) { _, _ in .shirtBlueDk }
        // Right: (28, 20) to (31, 31)
        fillRegion(&skinVM.project.baseLayer, x: 28, y: 20, w: 4, h: 12) { _, _ in .shirtBlueDk }
        // Top/Bottom
        fillRegion(&skinVM.project.baseLayer, x: 20, y: 16, w: 8, h: 4) { _, _ in .shirtBlue }
        fillRegion(&skinVM.project.baseLayer, x: 28, y: 16, w: 8, h: 4) { _, _ in .shirtBlueDk }

        // Right Arm UV: base origin (40, 16)
        fillRegion(&skinVM.project.baseLayer, x: 40, y: 16, w: 16, h: 16) { _, _ in .shirtBlue }
        // Unterarm = Haut
        fillRegion(&skinVM.project.baseLayer, x: 44, y: 24, w: 4, h: 8) { _, _ in .skinTone }

        // Left Arm UV: base origin (32, 48)
        fillRegion(&skinVM.project.baseLayer, x: 32, y: 48, w: 16, h: 16) { _, _ in .shirtBlue }
        fillRegion(&skinVM.project.baseLayer, x: 36, y: 56, w: 4, h: 8) { _, _ in .skinTone }

        // Right Leg UV: base origin (0, 16)
        fillRegion(&skinVM.project.baseLayer, x: 0, y: 16, w: 16, h: 16) { _, py in
            py < 8 ? .pantsBrown : .shoeDark
        }

        // Left Leg UV: base origin (16, 48)
        fillRegion(&skinVM.project.baseLayer, x: 16, y: 48, w: 16, h: 16) { _, py in
            py < 8 ? .pantsBrown : .shoeDark
        }

        skinVM.refreshEditCanvas()
    }

    // MARK: - 4. Painting Editor: Landschaft

    static func fillPainting(_ paintingVM: PaintingViewModel) {
        paintingVM.project.name = "sunset_landscape"
        let w = paintingVM.project.canvas.width
        let h = paintingVM.project.canvas.height

        for y in 0..<h {
            for x in 0..<w {
                let relY = Double(y) / Double(h)

                if relY < 0.55 {
                    // Himmel
                    if x == w / 4 && y >= 2 && y <= 5 { // Sonne
                        paintingVM.project.canvas.setPixel(at: x, y: y, color: .sunYellow)
                    } else if relY < 0.15 {
                        paintingVM.project.canvas.setPixel(at: x, y: y, color: .skyBlue)
                    } else if relY < 0.3 {
                        // Wolken
                        let isCloud = (x + y * 3) % 11 < 3 && relY < 0.25
                        paintingVM.project.canvas.setPixel(at: x, y: y, color: isCloud ? .cloudWhite : .skyBlue)
                    } else {
                        paintingVM.project.canvas.setPixel(at: x, y: y, color: .skyBlue)
                    }
                } else if relY < 0.7 {
                    // Berge
                    let peak = abs(Double(x) / Double(w) - 0.5) * 2.0
                    if peak + relY < 1.0 {
                        paintingVM.project.canvas.setPixel(at: x, y: y, color: relY < 0.6 ? .mountainSnow : .mountainGrey)
                    } else {
                        paintingVM.project.canvas.setPixel(at: x, y: y, color: .skyBlue)
                    }
                } else {
                    // Wiese
                    let noise = (x * 7 + y * 3) % 5
                    paintingVM.project.canvas.setPixel(at: x, y: y, color: noise < 2 ? .fieldLight : .fieldGreen)
                }
            }
        }
    }

    // MARK: - 5. Entity Editor: Creeper

    static func fillEntity(_ entityVM: EntityViewModel) {
        entityVM.project.name = "creeper"
        let texW = entityVM.project.entityType.textureWidth
        let texH = entityVM.project.entityType.textureHeight

        // Gesamte Textur mit Creeper-Grün füllen
        for y in 0..<texH {
            for x in 0..<texW {
                let noise = (x * 5 + y * 7) % 7
                let color: Color = noise < 2 ? .creeperDark : (noise == 6 ? .creeperLight : .creeperGreen)
                entityVM.project.texture.setPixel(at: x, y: y, color: color)
            }
        }

        // Creeper-Gesicht auf Front-Face des Kopfes
        // Creeper Head UV: origin (0, 0), d=8, w=8, h=8 → Front face at (8, 8) to (15, 15)
        // Augen: 2 Quadrate + Mund
        let facePixels: [(Int, Int)] = [
            // Linkes Auge (4x4 relativ)
            (9, 10), (10, 10), (9, 11), (10, 11),
            (9, 12), (10, 12), (9, 13), (10, 13),
            // Rechtes Auge
            (13, 10), (14, 10), (13, 11), (14, 11),
            (13, 12), (14, 12), (13, 13), (14, 13),
            // Mund
            (11, 12), (12, 12),
            (10, 13), (11, 13), (12, 13), (13, 13),
            (10, 14), (11, 14), (12, 14), (13, 14),
            (11, 15), (12, 15),
        ]
        for (x, y) in facePixels {
            entityVM.project.texture.setPixel(at: x, y: y, color: .creeperBlack)
        }

        entityVM.refreshEditCanvas()
    }

    // MARK: - 6. Armor Editor: Diamant-Rüstung

    static func fillArmor(_ armorVM: ArmorViewModel) {
        armorVM.project.name = "diamond_armor"

        // Layer 1: Helmet, Chestplate, Boots (64×32)
        for y in 0..<32 {
            for x in 0..<64 {
                let noise = (x * 3 + y * 5) % 6
                let color: Color = noise < 2 ? .armorDiaDark : (noise == 5 ? .armorDiaLight : .armorDiamond)
                armorVM.project.layer1.setPixel(at: x, y: y, color: color)
            }
        }

        // Layer 2: Leggings (64×32)
        for y in 0..<32 {
            for x in 0..<64 {
                let noise = (x * 7 + y * 3) % 6
                let color: Color = noise < 2 ? .armorDiaDark : (noise == 5 ? .armorDiaLight : .armorDiamond)
                armorVM.project.layer2.setPixel(at: x, y: y, color: color)
            }
        }

        armorVM.refreshEditCanvas()
    }

    // MARK: - 7. Recipe Editor: Diamantschwert

    static func fillRecipe(_ recipeVM: RecipeViewModel) {
        recipeVM.recipe.name = "diamond_sword"
        recipeVM.recipe.type = .shaped

        let diamond = RecipeSlot(
            itemID: "minecraft:diamond",
            displayName: "Diamant",
            color: Color(red: 0.4, green: 0.9, blue: 0.9)
        )
        let stick = RecipeSlot(
            itemID: "minecraft:stick",
            displayName: "Stock",
            color: Color(red: 0.6, green: 0.4, blue: 0.2)
        )
        let result = RecipeSlot(
            itemID: "minecraft:diamond_sword",
            displayName: "Diamantschwert",
            color: Color(red: 0.4, green: 0.9, blue: 0.9)
        )

        // Grid (3×3): Diamant oben Mitte, Diamant Mitte Mitte, Stock unten Mitte
        recipeVM.recipe.setSlot(at: 1, y: 0, slot: diamond)
        recipeVM.recipe.setSlot(at: 1, y: 1, slot: diamond)
        recipeVM.recipe.setSlot(at: 1, y: 2, slot: stick)
        recipeVM.recipe.result = result
        recipeVM.recipe.resultCount = 1
    }

    // MARK: - Alle befüllen

    static func loadAll(
        blockVM: BlockViewModel,
        itemVM: ItemViewModel,
        skinVM: SkinViewModel,
        paintingVM: PaintingViewModel,
        entityVM: EntityViewModel,
        armorVM: ArmorViewModel,
        recipeVM: RecipeViewModel
    ) {
        fillBlock(blockVM)
        fillItem(itemVM)
        fillSkin(skinVM)
        fillPainting(paintingVM)
        fillEntity(entityVM)
        fillArmor(armorVM)
        fillRecipe(recipeVM)
    }

    // MARK: - Helpers

    private static func fillFace(_ project: inout BlockProject, face: FaceType, colorForPixel: (Int, Int) -> Color) {
        let size = project.gridSize
        for y in 0..<size {
            for x in 0..<size {
                project.faces[face]?.frames[0].setPixel(at: x, y: y, color: colorForPixel(x, y))
            }
        }
    }

    private static func fillRegion(_ canvas: inout PixelCanvas, x: Int, y: Int, w: Int, h: Int, colorForPixel: (Int, Int) -> Color) {
        for py in 0..<h {
            for px in 0..<w {
                canvas.setPixel(at: x + px, y: y + py, color: colorForPixel(px, py))
            }
        }
    }
}
