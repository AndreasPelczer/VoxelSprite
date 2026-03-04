//
//  RecipeViewModel.swift
//  VoxelSprite
//
//  Verwaltet Crafting Recipes.
//  Zuständig für: Grid-Bearbeitung, Rezept-Verwaltung, JSON-Export.
//

import SwiftUI
import Combine

class RecipeViewModel: ObservableObject {

    // MARK: - Published State

    /// Aktives Rezept
    @Published var recipe: CraftingRecipe

    /// Aktuell ausgewähltes Item für die Platzierung
    @Published var selectedItem: MinecraftItems.ItemEntry?

    /// Custom Item-ID (für nicht in der Liste enthaltene Items)
    @Published var customItemID: String = ""

    /// Custom Item-Name
    @Published var customItemName: String = ""

    // MARK: - Init

    init() {
        self.recipe = CraftingRecipe()
    }

    // MARK: - Grid-Operationen

    /// Platziert das ausgewählte Item in einem Grid-Slot
    func placeItem(at index: Int) {
        guard index >= 0, index < 9 else { return }

        if let item = selectedItem {
            recipe.grid[index] = RecipeSlot(
                itemID: item.id,
                displayName: item.name,
                color: item.color
            )
        } else if !customItemID.isEmpty {
            recipe.grid[index] = RecipeSlot(
                itemID: customItemID,
                displayName: customItemName.isEmpty ? customItemID : customItemName,
                color: .orange
            )
        }
    }

    /// Setzt das Ergebnis-Item
    func setResult() {
        if let item = selectedItem {
            recipe.result = RecipeSlot(
                itemID: item.id,
                displayName: item.name,
                color: item.color
            )
        } else if !customItemID.isEmpty {
            recipe.result = RecipeSlot(
                itemID: customItemID,
                displayName: customItemName.isEmpty ? customItemID : customItemName,
                color: .orange
            )
        }
    }

    /// Leert einen Grid-Slot
    func clearSlot(at index: Int) {
        guard index >= 0, index < 9 else { return }
        recipe.grid[index] = .empty
    }

    /// Leert das gesamte Grid
    func clearGrid() {
        recipe.grid = Array(repeating: .empty, count: 9)
    }

    /// Leert das Ergebnis
    func clearResult() {
        recipe.result = .empty
    }

    // MARK: - Neues Rezept

    func newRecipe(type: RecipeType = .shaped) {
        recipe = CraftingRecipe(type: type)
    }

    // MARK: - JSON-Export

    /// Exportiert das Rezept als JSON-String
    func exportJSON() -> String {
        let json = recipe.toJSON()
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    /// Exportiert das Rezept als Data
    func exportJSONData() -> Data? {
        let json = recipe.toJSON()
        return try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
    }
}
