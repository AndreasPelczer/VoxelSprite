//
//  ResourcepackViewModel.swift
//  VoxelSprite
//
//  Verwaltet das Multi-Asset Resourcepack-Projekt.
//  Bündelt Blöcke, Items, Paintings und Recipes.
//

import SwiftUI
import Combine

class ResourcepackViewModel: ObservableObject {

    // MARK: - Published State

    @Published var project: ResourcepackProject

    /// Aktuell bearbeiteter Block-Index (-1 = keiner)
    @Published var activeBlockIndex: Int = -1

    /// Aktuell bearbeiteter Item-Index (-1 = keiner)
    @Published var activeItemIndex: Int = -1

    /// Aktuell bearbeitetes Painting-Index (-1 = keiner)
    @Published var activePaintingIndex: Int = -1

    /// Aktuell bearbeitetes Rezept-Index (-1 = keiner)
    @Published var activeRecipeIndex: Int = -1

    /// Aktuell bearbeiteter Entity-Index (-1 = keiner)
    @Published var activeEntityIndex: Int = -1

    /// Aktuell bearbeiteter Armor-Index (-1 = keiner)
    @Published var activeArmorIndex: Int = -1

    // MARK: - Init

    init() {
        self.project = ResourcepackProject()
    }

    // MARK: - Block-Operationen

    func addBlock() {
        let count = project.blocks.count
        project.addBlock("block_\(count + 1)")
        activeBlockIndex = project.blocks.count - 1
    }

    func removeBlock(at index: Int) {
        project.removeBlock(at: index)
        if activeBlockIndex >= project.blocks.count {
            activeBlockIndex = project.blocks.count - 1
        }
    }

    func selectBlock(_ index: Int) {
        activeBlockIndex = index
        activeItemIndex = -1
        activePaintingIndex = -1
        activeRecipeIndex = -1
        activeEntityIndex = -1
        activeArmorIndex = -1
    }

    // MARK: - Item-Operationen

    func addItem() {
        let count = project.items.count
        project.addItem("item_\(count + 1)")
        activeItemIndex = project.items.count - 1
    }

    func removeItem(at index: Int) {
        project.removeItem(at: index)
        if activeItemIndex >= project.items.count {
            activeItemIndex = project.items.count - 1
        }
    }

    func selectItem(_ index: Int) {
        activeBlockIndex = -1
        activeItemIndex = index
        activePaintingIndex = -1
        activeRecipeIndex = -1
        activeEntityIndex = -1
        activeArmorIndex = -1
    }

    // MARK: - Painting-Operationen

    func addPainting() {
        let count = project.paintings.count
        project.addPainting("painting_\(count + 1)")
        activePaintingIndex = project.paintings.count - 1
    }

    func removePainting(at index: Int) {
        project.removePainting(at: index)
        if activePaintingIndex >= project.paintings.count {
            activePaintingIndex = project.paintings.count - 1
        }
    }

    func selectPainting(_ index: Int) {
        activeBlockIndex = -1
        activeItemIndex = -1
        activePaintingIndex = index
        activeRecipeIndex = -1
        activeEntityIndex = -1
        activeArmorIndex = -1
    }

    // MARK: - Recipe-Operationen

    func addRecipe() {
        let count = project.recipes.count
        project.addRecipe("recipe_\(count + 1)")
        activeRecipeIndex = project.recipes.count - 1
    }

    func removeRecipe(at index: Int) {
        project.removeRecipe(at: index)
        if activeRecipeIndex >= project.recipes.count {
            activeRecipeIndex = project.recipes.count - 1
        }
    }

    func selectRecipe(_ index: Int) {
        activeBlockIndex = -1
        activeItemIndex = -1
        activePaintingIndex = -1
        activeRecipeIndex = index
        activeEntityIndex = -1
        activeArmorIndex = -1
    }

    // MARK: - Entity-Operationen

    func addEntity() {
        let count = project.entities.count
        project.addEntity("entity_\(count + 1)")
        activeEntityIndex = project.entities.count - 1
    }

    func removeEntity(at index: Int) {
        project.removeEntity(at: index)
        if activeEntityIndex >= project.entities.count {
            activeEntityIndex = project.entities.count - 1
        }
    }

    func selectEntity(_ index: Int) {
        activeBlockIndex = -1
        activeItemIndex = -1
        activePaintingIndex = -1
        activeRecipeIndex = -1
        activeEntityIndex = index
        activeArmorIndex = -1
    }

    // MARK: - Armor-Operationen

    func addArmor() {
        let count = project.armors.count
        project.addArmor("armor_\(count + 1)")
        activeArmorIndex = project.armors.count - 1
    }

    func removeArmor(at index: Int) {
        project.removeArmor(at: index)
        if activeArmorIndex >= project.armors.count {
            activeArmorIndex = project.armors.count - 1
        }
    }

    func selectArmor(_ index: Int) {
        activeBlockIndex = -1
        activeItemIndex = -1
        activePaintingIndex = -1
        activeRecipeIndex = -1
        activeEntityIndex = -1
        activeArmorIndex = index
    }

    // MARK: - Aktives Asset

    var activeAssetName: String {
        if activeBlockIndex >= 0, activeBlockIndex < project.blocks.count {
            return project.blocks[activeBlockIndex].name
        }
        if activeItemIndex >= 0, activeItemIndex < project.items.count {
            return project.items[activeItemIndex].name
        }
        if activePaintingIndex >= 0, activePaintingIndex < project.paintings.count {
            return project.paintings[activePaintingIndex].name
        }
        if activeRecipeIndex >= 0, activeRecipeIndex < project.recipes.count {
            return project.recipes[activeRecipeIndex].name
        }
        if activeEntityIndex >= 0, activeEntityIndex < project.entities.count {
            return project.entities[activeEntityIndex].name
        }
        if activeArmorIndex >= 0, activeArmorIndex < project.armors.count {
            return project.armors[activeArmorIndex].name
        }
        return project.name
    }

    // MARK: - Import aktuelle Editoren

    /// Importiert das aktuelle Block-Projekt in das Resourcepack
    func importCurrentBlock(from blockVM: BlockViewModel) {
        var block = blockVM.project
        block.namespace = project.namespace
        project.blocks.append(block)
        activeBlockIndex = project.blocks.count - 1
    }

    /// Importiert das aktuelle Item-Projekt
    func importCurrentItem(from itemVM: ItemViewModel) {
        var item = itemVM.project
        item.namespace = project.namespace
        project.items.append(item)
        activeItemIndex = project.items.count - 1
    }

    /// Importiert das aktuelle Painting-Projekt
    func importCurrentPainting(from paintingVM: PaintingViewModel) {
        var painting = paintingVM.project
        painting.namespace = project.namespace
        project.paintings.append(painting)
        activePaintingIndex = project.paintings.count - 1
    }

    /// Importiert das aktuelle Rezept
    func importCurrentRecipe(from recipeVM: RecipeViewModel) {
        var recipe = recipeVM.recipe
        recipe.namespace = project.namespace
        project.recipes.append(recipe)
        activeRecipeIndex = project.recipes.count - 1
    }

    /// Importiert das aktuelle Entity-Projekt
    func importCurrentEntity(from entityVM: EntityViewModel) {
        var entity = entityVM.project
        entity.namespace = project.namespace
        project.entities.append(entity)
        activeEntityIndex = project.entities.count - 1
    }

    /// Importiert das aktuelle Armor-Projekt
    func importCurrentArmor(from armorVM: ArmorViewModel) {
        var armor = armorVM.project
        armor.namespace = project.namespace
        project.armors.append(armor)
        activeArmorIndex = project.armors.count - 1
    }
}
