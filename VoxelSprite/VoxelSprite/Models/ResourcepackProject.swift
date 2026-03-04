//
//  ResourcepackProject.swift
//  VoxelSprite
//
//  Multi-Asset Resourcepack-Projekt.
//  Bündelt mehrere Blöcke, Items und Paintings in einem Resourcepack.
//  Enthält auch Crafting Recipes für den Datapack-Export.
//

import SwiftUI

// MARK: - Asset Entry

/// Ein einzelnes Asset im Resourcepack
struct AssetEntry: Identifiable {
    let id = UUID()
    var type: AssetType
    var name: String

    enum AssetType: String, CaseIterable, Identifiable {
        case block    = "Block"
        case item     = "Item"
        case painting = "Painting"
        case entity   = "Entity"
        case armor    = "Armor"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .block:    return "cube"
            case .item:     return "shield"
            case .painting: return "photo.artframe"
            case .entity:   return "hare"
            case .armor:    return "shield.lefthalf.filled"
            }
        }
    }
}

// MARK: - Resourcepack Project

struct ResourcepackProject {

    /// Name des Resourcepacks
    var name: String

    /// Namespace
    var namespace: String

    /// Ziel-Version
    var targetVersion: BlockProject.TargetVersion

    /// Block-Projekte
    var blocks: [BlockProject]

    /// Item-Projekte
    var items: [ItemProject]

    /// Painting-Projekte
    var paintings: [PaintingProject]

    /// Crafting Recipes
    var recipes: [CraftingRecipe]

    /// Entity-Projekte
    var entities: [EntityProject]

    /// Armor-Projekte
    var armors: [ArmorProject]

    // MARK: - Init

    init(
        name: String = "my_resourcepack",
        namespace: String = "custom",
        targetVersion: BlockProject.TargetVersion = .java
    ) {
        self.name = name
        self.namespace = namespace
        self.targetVersion = targetVersion
        self.blocks = []
        self.items = []
        self.paintings = []
        self.recipes = []
        self.entities = []
        self.armors = []
    }

    // MARK: - Asset-Verwaltung

    /// Gesamtanzahl aller Assets
    var totalAssetCount: Int {
        blocks.count + items.count + paintings.count + entities.count + armors.count
    }

    /// Alle Assets als flache Liste
    var allAssets: [AssetEntry] {
        var result: [AssetEntry] = []
        for block in blocks {
            result.append(AssetEntry(type: .block, name: block.name))
        }
        for item in items {
            result.append(AssetEntry(type: .item, name: item.name))
        }
        for painting in paintings {
            result.append(AssetEntry(type: .painting, name: painting.name))
        }
        for entity in entities {
            result.append(AssetEntry(type: .entity, name: entity.name))
        }
        for armor in armors {
            result.append(AssetEntry(type: .armor, name: armor.name))
        }
        return result
    }

    // MARK: - Block-Operationen

    mutating func addBlock(_ name: String = "new_block") {
        var block = BlockProject(name: name, namespace: namespace)
        block.name = name
        blocks.append(block)
    }

    mutating func removeBlock(at index: Int) {
        guard index >= 0, index < blocks.count else { return }
        blocks.remove(at: index)
    }

    // MARK: - Item-Operationen

    mutating func addItem(_ name: String = "new_item") {
        var item = ItemProject(name: name, namespace: namespace)
        item.name = name
        items.append(item)
    }

    mutating func removeItem(at index: Int) {
        guard index >= 0, index < items.count else { return }
        items.remove(at: index)
    }

    // MARK: - Painting-Operationen

    mutating func addPainting(_ name: String = "new_painting") {
        var painting = PaintingProject(name: name, namespace: namespace)
        painting.name = name
        paintings.append(painting)
    }

    mutating func removePainting(at index: Int) {
        guard index >= 0, index < paintings.count else { return }
        paintings.remove(at: index)
    }

    // MARK: - Recipe-Operationen

    mutating func addRecipe(_ name: String = "new_recipe") {
        var recipe = CraftingRecipe(name: name, namespace: namespace)
        recipe.name = name
        recipes.append(recipe)
    }

    mutating func removeRecipe(at index: Int) {
        guard index >= 0, index < recipes.count else { return }
        recipes.remove(at: index)
    }

    // MARK: - Entity-Operationen

    mutating func addEntity(_ name: String = "new_entity") {
        var entity = EntityProject(name: name, namespace: namespace)
        entity.name = name
        entities.append(entity)
    }

    mutating func removeEntity(at index: Int) {
        guard index >= 0, index < entities.count else { return }
        entities.remove(at: index)
    }

    // MARK: - Armor-Operationen

    mutating func addArmor(_ name: String = "new_armor") {
        var armor = ArmorProject(name: name, namespace: namespace)
        armor.name = name
        armors.append(armor)
    }

    mutating func removeArmor(at index: Int) {
        guard index >= 0, index < armors.count else { return }
        armors.remove(at: index)
    }
}
