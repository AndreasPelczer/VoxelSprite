//
//  ColorPaletteView.swift
//  PlanktonSpriteApp
//
//  Created by Andreas Pelczer on 27.02.26.
//


import SwiftUI

/// Die Farbpalette unter dem Canvas.
/// Vordefinierte Farben + Custom Color Picker.
struct ColorPaletteView: View {

    @EnvironmentObject var canvasVM: CanvasViewModel
    @EnvironmentObject var paletteManager: PaletteManager

    /// Name für neue Palette
    @State private var newPaletteName: String = ""
    @State private var showSavePalette: Bool = false
    /// Aktuell geladene Saved Palette (nil = Standard)
    @State private var activeSavedPalette: SavedPalette?
    
    // MARK: - Farbpalette
    
    /// Vordefinierte Farben – Ozean- und Plankton-Töne,
    /// plus Standardfarben die man immer braucht.
    private let palette: [Color] = [
        // Reihe 1: Basics
        .black, .white,
        Color(red: 0.4, green: 0.4, blue: 0.4),       // Grau
        Color(red: 0.8, green: 0.8, blue: 0.8),       // Hellgrau
        
        // Reihe 2: Warme Töne
        Color(red: 1.0, green: 0.0, blue: 0.0),       // Rot
        Color(red: 1.0, green: 0.4, blue: 0.0),       // Orange
        Color(red: 1.0, green: 0.8, blue: 0.0),       // Gelb
        Color(red: 1.0, green: 1.0, blue: 0.4),       // Hellgelb
        
        // Reihe 3: Grüntöne (Algen, Plankton)
        Color(red: 0.0, green: 0.6, blue: 0.0),       // Dunkelgrün
        Color(red: 0.2, green: 0.8, blue: 0.2),       // Grün
        Color(red: 0.4, green: 1.0, blue: 0.4),       // Hellgrün
        Color(red: 0.6, green: 0.85, blue: 0.45),     // Limettengrün
        
        // Reihe 4: Blautöne (Ozean, Tiefsee)
        Color(red: 0.0, green: 0.2, blue: 0.4),       // Tiefsee
        Color(red: 0.0, green: 0.4, blue: 1.0),       // Blau
        Color(red: 0.0, green: 0.7, blue: 0.85),      // Türkis
        Color(red: 0.56, green: 0.88, blue: 0.94),    // Hellblau
        
        // Reihe 5: Violett / Biolumineszenz
        Color(red: 0.6, green: 0.2, blue: 1.0),       // Violett
        Color(red: 1.0, green: 0.4, blue: 0.8),       // Pink
        Color(red: 0.33, green: 0.2, blue: 0.5),      // Dunkelviolett
        Color(red: 0.8, green: 0.6, blue: 1.0),       // Lavendel
        
        // Reihe 6: Erd-/Sandtöne
        Color(red: 0.6, green: 0.4, blue: 0.2),       // Braun
        Color(red: 0.9, green: 0.75, blue: 0.5),      // Sand
        Color(red: 0.4, green: 0.25, blue: 0.13),     // Dunkelbraun
        Color(red: 1.0, green: 0.82, blue: 0.4),      // Gold
    ]
    
    /// Anzahl Spalten im Grid
    private let columns = 4
    
    /// Die aktuell angezeigte Palette (Standard oder gespeichert)
    private var displayPalette: [Color] {
        if let saved = activeSavedPalette {
            return saved.swiftUIColors
        }
        return palette
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // MARK: - Aktuelle Farbe + Picker

            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(canvasVM.currentColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )

                ColorPicker("", selection: $canvasVM.currentColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 32, height: 32)
                    .help("Eigene Farbe wählen")

                Spacer()

                Text(hexString(for: canvasVM.currentColor))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // MARK: - Farbpalette Grid

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(22), spacing: 3), count: columns),
                spacing: 3
            ) {
                ForEach(Array(displayPalette.enumerated()), id: \.offset) { _, color in
                    colorSwatch(color)
                }
            }

            // MARK: - Saved Palettes

            HStack(spacing: 4) {
                // Zurück zur Standardpalette
                if activeSavedPalette != nil {
                    Button {
                        activeSavedPalette = nil
                    } label: {
                        Text("Standard")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                // Gespeicherte Paletten laden
                if !paletteManager.savedPalettes.isEmpty {
                    Menu {
                        ForEach(paletteManager.savedPalettes) { savedPalette in
                            Button(savedPalette.name) {
                                activeSavedPalette = savedPalette
                            }
                        }
                    } label: {
                        Label("Paletten", systemImage: "paintpalette")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .controlSize(.mini)
                }

                Spacer()

                // Aktuelle Palette speichern
                Button {
                    showSavePalette.toggle()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Palette speichern")
            }

            if showSavePalette {
                HStack(spacing: 4) {
                    TextField("Name", text: $newPaletteName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 10))
                        .controlSize(.mini)
                    Button("OK") {
                        let name = newPaletteName.isEmpty ? "Palette \(paletteManager.savedPalettes.count + 1)" : newPaletteName
                        paletteManager.savePalette(name: name, colors: displayPalette)
                        newPaletteName = ""
                        showSavePalette = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Subviews
    
    /// Einzelnes Farbfeld in der Palette
    private func colorSwatch(_ color: Color) -> some View {
        let isSelected = isSameColor(color, canvasVM.currentColor)
        
        return Button {
            canvasVM.currentColor = color
            // Wenn Radierer aktiv, automatisch zum Stift wechseln
            if canvasVM.currentTool == .eraser {
                canvasVM.currentTool = .pen
            }
        } label: {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isSelected ? .white : .white.opacity(0.15),
                            lineWidth: isSelected ? 2 : 0.5
                        )
                )
                .scaleEffect(isSelected ? 1.15 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Hilfsfunktionen
    
    /// Vergleicht zwei SwiftUI Colors über ihre Komponenten.
    /// Direkter == Vergleich funktioniert bei Color nicht zuverlässig,
    /// weil Color eine View ist, kein Wert.
    private func isSameColor(_ a: Color, _ b: Color) -> Bool {
        guard let ac = a.cgColorComponents,
              let bc = b.cgColorComponents else { return false }
        let threshold: CGFloat = 0.01
        return abs(ac.r - bc.r) < threshold
            && abs(ac.g - bc.g) < threshold
            && abs(ac.b - bc.b) < threshold
    }
    
    /// Erzeugt einen Hex-String aus einer SwiftUI Color.
    private func hexString(for color: Color) -> String {
        guard let c = color.cgColorComponents else { return "#000000" }
        let r = Int(c.r * 255)
        let g = Int(c.g * 255)
        let b = Int(c.b * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
