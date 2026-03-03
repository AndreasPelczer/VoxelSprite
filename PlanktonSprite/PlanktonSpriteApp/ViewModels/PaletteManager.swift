//
//  PaletteManager.swift
//  PlanktonSpriteApp
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

    /// Konvertiert die Hex-Strings zurück in SwiftUI Colors
    var swiftUIColors: [Color] {
        colors.map { Color(hex: $0) }
    }
}

/// Verwaltet das Speichern und Laden von Farbpaletten
class PaletteManager: ObservableObject {

    @Published var savedPalettes: [SavedPalette] = []

    private let storageKey = "PlanktonSprite_SavedPalettes"

    init() {
        loadPalettes()
    }

    /// Speichert eine neue Palette
    func savePalette(name: String, colors: [Color]) {
        let palette = SavedPalette(name: name, colors: colors)
        savedPalettes.append(palette)
        persistPalettes()
    }

    /// Löscht eine Palette
    func deletePalette(_ palette: SavedPalette) {
        savedPalettes.removeAll { $0.id == palette.id }
        persistPalettes()
    }

    /// Lädt Paletten aus UserDefaults
    private func loadPalettes() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let palettes = try? JSONDecoder().decode([SavedPalette].self, from: data) else {
            return
        }
        savedPalettes = palettes
    }

    /// Persistiert Paletten in UserDefaults
    private func persistPalettes() {
        guard let data = try? JSONEncoder().encode(savedPalettes) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
