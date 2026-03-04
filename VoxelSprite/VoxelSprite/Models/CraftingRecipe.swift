//
//  CraftingRecipe.swift
//  VoxelSprite
//
//  Datenmodell für Minecraft Crafting Recipes.
//  Unterstützt Shaped (3×3 Grid) und Shapeless Recipes.
//  Exportiert Minecraft-kompatible Recipe JSON.
//

import SwiftUI

// MARK: - Recipe Type

enum RecipeType: String, CaseIterable, Identifiable, Codable {
    case shaped    = "Shaped"
    case shapeless = "Shapeless"
    case smelting  = "Smelting"
    case blasting  = "Blasting"
    case smoking   = "Smoking"

    var id: String { rawValue }

    var minecraftType: String {
        switch self {
        case .shaped:    return "minecraft:crafting_shaped"
        case .shapeless: return "minecraft:crafting_shapeless"
        case .smelting:  return "minecraft:smelting"
        case .blasting:  return "minecraft:blasting"
        case .smoking:   return "minecraft:smoking"
        }
    }

    var iconName: String {
        switch self {
        case .shaped:    return "square.grid.3x3"
        case .shapeless: return "square.grid.3x3.fill"
        case .smelting:  return "flame"
        case .blasting:  return "flame.fill"
        case .smoking:   return "smoke"
        }
    }

    var description: String {
        switch self {
        case .shaped:    return "3×3 Grid (Position zählt)"
        case .shapeless: return "Beliebige Anordnung"
        case .smelting:  return "Ofen"
        case .blasting:  return "Schmelzofen"
        case .smoking:   return "Räucherofen"
        }
    }

    var usesGrid: Bool {
        self == .shaped
    }

    var usesSingleInput: Bool {
        self == .smelting || self == .blasting || self == .smoking
    }
}

// MARK: - Recipe Slot

/// Ein Slot im 3×3 Grid oder in der Zutatenliste
struct RecipeSlot: Identifiable, Equatable {
    let id = UUID()
    var itemID: String        // z.B. "minecraft:diamond", "minecraft:stick"
    var displayName: String   // Anzeigename
    var color: Color          // Farbe für die Visualisierung

    static let empty = RecipeSlot(itemID: "", displayName: "", color: .clear)

    var isEmpty: Bool { itemID.isEmpty }
}

// MARK: - Common Minecraft Items (für Schnellauswahl)

struct MinecraftItems {
    struct ItemEntry: Identifiable {
        let id: String  // minecraft:diamond
        let name: String
        let color: Color
        let icon: String
    }

    static let common: [ItemEntry] = [
        ItemEntry(id: "minecraft:diamond", name: "Diamant", color: Color(red: 0.4, green: 0.9, blue: 0.9), icon: "diamond"),
        ItemEntry(id: "minecraft:iron_ingot", name: "Eisenbarren", color: Color(red: 0.85, green: 0.85, blue: 0.85), icon: "rectangle.fill"),
        ItemEntry(id: "minecraft:gold_ingot", name: "Goldbarren", color: Color(red: 1.0, green: 0.85, blue: 0.2), icon: "rectangle.fill"),
        ItemEntry(id: "minecraft:stick", name: "Stock", color: Color(red: 0.6, green: 0.4, blue: 0.2), icon: "line.diagonal"),
        ItemEntry(id: "minecraft:oak_planks", name: "Eichenbretter", color: Color(red: 0.75, green: 0.6, blue: 0.35), icon: "square.fill"),
        ItemEntry(id: "minecraft:cobblestone", name: "Bruchstein", color: Color(red: 0.5, green: 0.5, blue: 0.5), icon: "square.fill"),
        ItemEntry(id: "minecraft:redstone", name: "Redstone", color: Color(red: 0.9, green: 0.1, blue: 0.1), icon: "bolt.fill"),
        ItemEntry(id: "minecraft:string", name: "Faden", color: Color(red: 0.9, green: 0.9, blue: 0.9), icon: "line.diagonal"),
        ItemEntry(id: "minecraft:leather", name: "Leder", color: Color(red: 0.65, green: 0.4, blue: 0.2), icon: "square.fill"),
        ItemEntry(id: "minecraft:coal", name: "Kohle", color: Color(red: 0.2, green: 0.2, blue: 0.2), icon: "diamond.fill"),
        ItemEntry(id: "minecraft:emerald", name: "Smaragd", color: Color(red: 0.2, green: 0.8, blue: 0.3), icon: "diamond"),
        ItemEntry(id: "minecraft:netherite_ingot", name: "Netheritbarren", color: Color(red: 0.3, green: 0.25, blue: 0.25), icon: "rectangle.fill"),
        ItemEntry(id: "minecraft:copper_ingot", name: "Kupferbarren", color: Color(red: 0.85, green: 0.55, blue: 0.35), icon: "rectangle.fill"),
        ItemEntry(id: "minecraft:glass", name: "Glas", color: Color(red: 0.8, green: 0.9, blue: 0.95), icon: "square"),
        ItemEntry(id: "minecraft:blaze_powder", name: "Lohenstaub", color: Color(red: 1.0, green: 0.7, blue: 0.0), icon: "sparkle"),
        ItemEntry(id: "minecraft:ender_pearl", name: "Enderperle", color: Color(red: 0.1, green: 0.5, blue: 0.5), icon: "circle.fill"),
    ]
}

// MARK: - Crafting Recipe

struct CraftingRecipe: Identifiable {
    let id = UUID()

    /// Name des Rezepts
    var name: String

    /// Namespace
    var namespace: String

    /// Rezept-Typ
    var type: RecipeType

    /// 3×3 Grid (row-major, 9 Slots)
    var grid: [RecipeSlot]

    /// Ergebnis
    var result: RecipeSlot

    /// Ergebnis-Anzahl
    var resultCount: Int

    /// Cooking-Zeit in Ticks (nur für Smelting/Blasting/Smoking)
    var cookingTime: Int

    /// XP-Belohnung (nur für Smelting/Blasting/Smoking)
    var experience: Double

    // MARK: - Init

    init(
        name: String = "custom_recipe",
        namespace: String = "minecraft",
        type: RecipeType = .shaped
    ) {
        self.name = name
        self.namespace = namespace
        self.type = type
        self.grid = Array(repeating: .empty, count: 9)
        self.result = .empty
        self.resultCount = 1
        self.cookingTime = 200
        self.experience = 0.1
    }

    // MARK: - Grid-Zugriff

    /// Slot an Position (x, y) — x: 0-2, y: 0-2
    func slot(at x: Int, y: Int) -> RecipeSlot {
        let index = y * 3 + x
        guard index >= 0 && index < 9 else { return .empty }
        return grid[index]
    }

    /// Setzt einen Slot
    mutating func setSlot(at x: Int, y: Int, slot: RecipeSlot) {
        let index = y * 3 + x
        guard index >= 0 && index < 9 else { return }
        grid[index] = slot
    }

    /// Setzt einen Slot per Index (0-8)
    mutating func setSlot(at index: Int, slot: RecipeSlot) {
        guard index >= 0 && index < 9 else { return }
        grid[index] = slot
    }

    /// Alle nicht-leeren Zutaten
    var ingredients: [RecipeSlot] {
        grid.filter { !$0.isEmpty }
    }

    /// Einzigartige Zutaten (nach itemID)
    var uniqueIngredients: [RecipeSlot] {
        var seen = Set<String>()
        return grid.compactMap { slot in
            guard !slot.isEmpty, !seen.contains(slot.itemID) else { return nil }
            seen.insert(slot.itemID)
            return slot
        }
    }

    // MARK: - JSON Export

    /// Generiert das Minecraft Recipe JSON
    func toJSON() -> [String: Any] {
        switch type {
        case .shaped:
            return shapedJSON()
        case .shapeless:
            return shapelessJSON()
        case .smelting, .blasting, .smoking:
            return cookingJSON()
        }
    }

    private func shapedJSON() -> [String: Any] {
        // Pattern bestimmen
        let unique = uniqueIngredients
        var charMap: [String: Character] = [:]
        let chars: [Character] = ["A", "B", "C", "D", "E", "F", "G", "H", "I"]
        for (i, slot) in unique.enumerated() {
            charMap[slot.itemID] = chars[i]
        }

        // Pattern-Zeilen
        var pattern: [String] = []
        for row in 0..<3 {
            var line = ""
            for col in 0..<3 {
                let slot = self.slot(at: col, y: row)
                if slot.isEmpty {
                    line += " "
                } else {
                    line += String(charMap[slot.itemID] ?? " ")
                }
            }
            pattern.append(line)
        }

        // Trim: Leere Zeilen oben/unten entfernen, leere Spalten links/rechts
        pattern = trimPattern(pattern)

        // Key-Map
        var key: [String: Any] = [:]
        for (itemID, char) in charMap {
            key[String(char)] = ["item": itemID]
        }

        var json: [String: Any] = [
            "type": type.minecraftType,
            "pattern": pattern,
            "key": key,
            "result": resultJSON()
        ]

        if !name.isEmpty {
            json["group"] = name
        }

        return json
    }

    private func shapelessJSON() -> [String: Any] {
        let ingredientList = ingredients.map { slot -> [String: String] in
            ["item": slot.itemID]
        }

        return [
            "type": type.minecraftType,
            "ingredients": ingredientList,
            "result": resultJSON()
        ]
    }

    private func cookingJSON() -> [String: Any] {
        let inputSlot = ingredients.first ?? .empty

        return [
            "type": type.minecraftType,
            "ingredient": ["item": inputSlot.itemID],
            "result": result.itemID,
            "experience": experience,
            "cookingtime": cookingTime
        ]
    }

    private func resultJSON() -> [String: Any] {
        var r: [String: Any] = ["id": result.itemID]
        if resultCount > 1 {
            r["count"] = resultCount
        }
        return r
    }

    private func trimPattern(_ pattern: [String]) -> [String] {
        var lines = pattern

        // Leere Zeilen oben entfernen
        while let first = lines.first, first.allSatisfy({ $0 == " " }) && lines.count > 1 {
            lines.removeFirst()
        }
        // Leere Zeilen unten entfernen
        while let last = lines.last, last.allSatisfy({ $0 == " " }) && lines.count > 1 {
            lines.removeLast()
        }

        // Leere Spalten links
        while lines.allSatisfy({ $0.first == " " }) && (lines.first?.count ?? 0) > 1 {
            lines = lines.map { String($0.dropFirst()) }
        }
        // Leere Spalten rechts
        while lines.allSatisfy({ $0.last == " " }) && (lines.first?.count ?? 0) > 1 {
            lines = lines.map { String($0.dropLast()) }
        }

        return lines
    }
}
