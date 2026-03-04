//
//  VoxelWorkspaceFile.swift
//  VoxelSprite
//
//  Serialisierbares Dateiformat für .voxelwork Workspace-Dateien.
//  Speichert den kompletten Zustand aller Editor-Modi:
//  Block, Item, Skin, Painting, Entity, Armor, Recipes.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Codable Canvas Helper

/// Serialisierbare Darstellung eines PixelCanvas.
/// Konvertiert Color-Werte in Hex-Strings (#RRGGBBAA).
struct CodableCanvas: Codable {
    var width: Int
    var height: Int
    var pixels: [[String?]]

    init(from canvas: PixelCanvas) {
        self.width = canvas.width
        self.height = canvas.height
        self.pixels = canvas.pixels.map { row in
            row.map { color -> String? in
                guard let c = color, let comp = c.cgColorComponents else { return nil }
                return String(format: "#%02X%02X%02X%02X",
                    Int(comp.r * 255),
                    Int(comp.g * 255),
                    Int(comp.b * 255),
                    Int(comp.a * 255))
            }
        }
    }

    func toCanvas() -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: height)
        for (y, row) in pixels.enumerated() {
            for (x, hexString) in row.enumerated() {
                if let hex = hexString {
                    canvas.setPixel(at: x, y: y, color: Color(hex: hex))
                }
            }
        }
        return canvas
    }
}

// MARK: - Workspace File

/// Komplette Workspace-Datei mit allen Editor-Zuständen.
struct VoxelWorkspaceFile: Codable {

    let version: Int

    // Einzelne Editor-Projekte
    var block: VoxelProjectFile?
    var skin: SkinData?
    var item: ItemData?
    var painting: PaintingData?
    var entity: EntityData?
    var armor: ArmorData?
    var recipe: RecipeData?

    // MARK: - Skin Data

    struct SkinData: Codable {
        var name: String
        var baseLayer: CodableCanvas
        var overlayLayer: CodableCanvas

        init(from project: SkinProject) {
            self.name = project.name
            self.baseLayer = CodableCanvas(from: project.baseLayer)
            self.overlayLayer = CodableCanvas(from: project.overlayLayer)
        }

        func toProject() -> SkinProject {
            var project = SkinProject(name: name)
            project.baseLayer = baseLayer.toCanvas()
            project.overlayLayer = overlayLayer.toCanvas()
            return project
        }
    }

    // MARK: - Item Data

    struct ItemData: Codable {
        var name: String
        var displayType: String
        var namespace: String
        var targetVersion: String
        var gridSize: Int
        var layers: [CodableCanvas]

        init(from project: ItemProject) {
            self.name = project.name
            self.displayType = project.displayType.rawValue
            self.namespace = project.namespace
            self.targetVersion = project.targetVersion.rawValue
            self.gridSize = project.gridSize
            self.layers = project.layers.map { CodableCanvas(from: $0) }
        }

        func toProject() -> ItemProject {
            var project = ItemProject(
                name: name,
                gridSize: gridSize,
                displayType: ItemDisplayType(rawValue: displayType) ?? .generated,
                namespace: namespace,
                targetVersion: BlockProject.TargetVersion(rawValue: targetVersion) ?? .java
            )
            if !layers.isEmpty {
                project.layers = layers.map { $0.toCanvas() }
            }
            return project
        }
    }

    // MARK: - Painting Data

    struct PaintingData: Codable {
        var name: String
        var size: String
        var namespace: String
        var canvas: CodableCanvas

        init(from project: PaintingProject) {
            self.name = project.name
            self.size = project.size.rawValue
            self.namespace = project.namespace
            self.canvas = CodableCanvas(from: project.canvas)
        }

        func toProject() -> PaintingProject {
            let paintingSize = PaintingSize(rawValue: size) ?? .s2x2
            var project = PaintingProject(name: name, size: paintingSize, namespace: namespace)
            project.canvas = canvas.toCanvas()
            return project
        }
    }

    // MARK: - Entity Data

    struct EntityData: Codable {
        var name: String
        var namespace: String
        var entityType: String
        var texture: CodableCanvas

        init(from project: EntityProject) {
            self.name = project.name
            self.namespace = project.namespace
            self.entityType = project.entityType.rawValue
            self.texture = CodableCanvas(from: project.texture)
        }

        func toProject() -> EntityProject {
            let type = EntityType(rawValue: entityType) ?? .creeper
            var project = EntityProject(name: name, namespace: namespace, entityType: type)
            project.texture = texture.toCanvas()
            return project
        }
    }

    // MARK: - Armor Data

    struct ArmorData: Codable {
        var name: String
        var namespace: String
        var material: String
        var layer1: CodableCanvas
        var layer2: CodableCanvas

        init(from project: ArmorProject) {
            self.name = project.name
            self.namespace = project.namespace
            self.material = project.material.rawValue
            self.layer1 = CodableCanvas(from: project.layer1)
            self.layer2 = CodableCanvas(from: project.layer2)
        }

        func toProject() -> ArmorProject {
            let mat = ArmorMaterial(rawValue: material) ?? .iron
            var project = ArmorProject(name: name, namespace: namespace, material: mat)
            project.layer1 = layer1.toCanvas()
            project.layer2 = layer2.toCanvas()
            return project
        }
    }

    // MARK: - Recipe Data

    struct RecipeSlotData: Codable {
        var itemID: String
        var displayName: String
        var colorHex: String

        init(from slot: RecipeSlot) {
            self.itemID = slot.itemID
            self.displayName = slot.displayName
            if let comp = slot.color.cgColorComponents {
                self.colorHex = String(format: "#%02X%02X%02X%02X",
                    Int(comp.r * 255), Int(comp.g * 255),
                    Int(comp.b * 255), Int(comp.a * 255))
            } else {
                self.colorHex = "#00000000"
            }
        }

        func toSlot() -> RecipeSlot {
            RecipeSlot(
                itemID: itemID,
                displayName: displayName,
                color: Color(hex: colorHex)
            )
        }
    }

    struct RecipeData: Codable {
        var name: String
        var namespace: String
        var type: String
        var grid: [RecipeSlotData]
        var result: RecipeSlotData
        var resultCount: Int
        var cookingTime: Int
        var experience: Double

        init(from recipe: CraftingRecipe) {
            self.name = recipe.name
            self.namespace = recipe.namespace
            self.type = recipe.type.rawValue
            self.grid = recipe.grid.map { RecipeSlotData(from: $0) }
            self.result = RecipeSlotData(from: recipe.result)
            self.resultCount = recipe.resultCount
            self.cookingTime = recipe.cookingTime
            self.experience = recipe.experience
        }

        func toRecipe() -> CraftingRecipe {
            var recipe = CraftingRecipe(
                name: name,
                namespace: namespace,
                type: RecipeType(rawValue: type) ?? .shaped
            )
            recipe.grid = grid.map { $0.toSlot() }
            recipe.result = result.toSlot()
            recipe.resultCount = resultCount
            recipe.cookingTime = cookingTime
            recipe.experience = experience
            return recipe
        }
    }

    // MARK: - Workspace erstellen

    init(
        blockProject: BlockProject,
        skinProject: SkinProject,
        itemProject: ItemProject,
        paintingProject: PaintingProject,
        entityProject: EntityProject,
        armorProject: ArmorProject,
        recipe: CraftingRecipe
    ) {
        self.version = 1
        self.block = VoxelProjectFile(from: blockProject)
        self.skin = SkinData(from: skinProject)
        self.item = ItemData(from: itemProject)
        self.painting = PaintingData(from: paintingProject)
        self.entity = EntityData(from: entityProject)
        self.armor = ArmorData(from: armorProject)
        self.recipe = RecipeData(from: recipe)
    }
}

// MARK: - FileDocument Wrapper

/// SwiftUI FileDocument-Wrapper für .voxelwork Workspace-Dateien
struct VoxelWorkspaceDocument: FileDocument {

    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "voxelwork") ?? .json]
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
