//
//  PaletteManager.swift
//  VoxelSprite
//
//  Verwaltet gespeicherte Farbpaletten.
//  Paletten werden als JSON in UserDefaults persistiert.
//

import SwiftUI
import Combine

/// Eine benannte Farbpalette
struct SavedPalette: Codable, Identifiable {
    let id: UUID
    var name: String
    var colors: [String] // Hex-Strings

    init(name: String, colors: [Color]) {
        self.id = UUID()
        self.name = name
        self.colors = colors.compactMap { color in
            guard let c = color.cgColorComponents else { return nil }
            return String(format: "#%02X%02X%02X", Int(c.r * 255), Int(c.g * 255), Int(c.b * 255))
        }
    }

    var swiftUIColors: [Color] {
        colors.map { Color(hex: $0) }
    }
}

/// Verwaltet das Speichern und Laden von Farbpaletten
class PaletteManager: ObservableObject {

    @Published var savedPalettes: [SavedPalette] = []

    private let storageKey = "VoxelSprite_SavedPalettes"

    init() {
        loadPalettes()
    }

    func savePalette(name: String, colors: [Color]) {
        let palette = SavedPalette(name: name, colors: colors)
        savedPalettes.append(palette)
        persistPalettes()
    }

    func deletePalette(_ palette: SavedPalette) {
        savedPalettes.removeAll { $0.id == palette.id }
        persistPalettes()
    }

    private func loadPalettes() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let palettes = try? JSONDecoder().decode([SavedPalette].self, from: data) else {
            return
        }
        savedPalettes = palettes
    }

    private func persistPalettes() {
        guard let data = try? JSONEncoder().encode(savedPalettes) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
