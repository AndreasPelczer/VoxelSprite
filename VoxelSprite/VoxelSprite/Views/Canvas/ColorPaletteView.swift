//
//  ColorPaletteView.swift
//  VoxelSprite
//
//  Die Farbpalette mit Minecraft-spezifischen Farben.
//  Vordefinierte Minecraft-Farbpalette + Custom Color Picker.
//

import SwiftUI

struct ColorPaletteView: View {

    @EnvironmentObject var canvasVM: CanvasViewModel
    @EnvironmentObject var paletteManager: PaletteManager

    @State private var newPaletteName: String = ""
    @State private var showSavePalette: Bool = false
    @State private var activeSavedPalette: SavedPalette?

    // MARK: - Minecraft Farbpalette

    private let palette: [Color] = [
        // Reihe 1: Stein & Erze
        Color(red: 0.50, green: 0.50, blue: 0.50),  // Stein
        Color(red: 0.40, green: 0.40, blue: 0.40),  // Dunkelstein
        Color(red: 0.69, green: 0.69, blue: 0.69),  // Hellstein
        Color(red: 0.25, green: 0.25, blue: 0.25),  // Kohle

        // Reihe 2: Holz
        Color(red: 0.65, green: 0.45, blue: 0.20),  // Eiche
        Color(red: 0.40, green: 0.25, blue: 0.13),  // Dunkeleiche
        Color(red: 0.85, green: 0.70, blue: 0.45),  // Birke
        Color(red: 0.55, green: 0.25, blue: 0.15),  // Akazie

        // Reihe 3: Erde & Sand
        Color(red: 0.55, green: 0.38, blue: 0.22),  // Erde
        Color(red: 0.45, green: 0.32, blue: 0.18),  // Dunkle Erde
        Color(red: 0.85, green: 0.80, blue: 0.55),  // Sand
        Color(red: 0.75, green: 0.55, blue: 0.30),  // Rotsand

        // Reihe 4: Gras & Pflanzen
        Color(red: 0.30, green: 0.60, blue: 0.15),  // Gras
        Color(red: 0.20, green: 0.45, blue: 0.10),  // Dunkelgras
        Color(red: 0.45, green: 0.75, blue: 0.25),  // Hellgras
        Color(red: 0.18, green: 0.35, blue: 0.08),  // Blätter

        // Reihe 5: Erze & Metalle
        Color(red: 0.90, green: 0.75, blue: 0.35),  // Gold
        Color(red: 0.85, green: 0.85, blue: 0.85),  // Eisen
        Color(red: 0.25, green: 0.70, blue: 0.80),  // Diamant
        Color(red: 0.35, green: 0.90, blue: 0.35),  // Smaragd

        // Reihe 6: Nether & End
        Color(red: 0.55, green: 0.10, blue: 0.10),  // Netherrack
        Color(red: 0.15, green: 0.08, blue: 0.20),  // Obsidian
        Color(red: 0.85, green: 0.85, blue: 0.55),  // Endstein
        Color(red: 0.40, green: 0.20, blue: 0.50),  // Purpur

        // Reihe 7: Basics
        .black, .white,
        Color(red: 1.0, green: 0.0, blue: 0.0),     // Rot (Redstone)
        Color(red: 0.0, green: 0.4, blue: 1.0),      // Blau (Lapislazuli)
    ]

    private let columns = 4

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

            // MARK: - Zuletzt benutzte Farben

            if !canvasVM.recentColors.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Zuletzt")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 3) {
                        ForEach(Array(canvasVM.recentColors.prefix(10).enumerated()), id: \.offset) { _, color in
                            colorSwatch(color, size: 18)
                        }
                        Spacer()
                    }
                }
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
                if activeSavedPalette != nil {
                    Button {
                        activeSavedPalette = nil
                    } label: {
                        Text("Minecraft")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

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

    private func colorSwatch(_ color: Color, size: CGFloat = 22) -> some View {
        let isSelected = isSameColor(color, canvasVM.currentColor)

        return Button {
            canvasVM.currentColor = color
            if canvasVM.currentTool == .eraser {
                canvasVM.currentTool = .pen
            }
        } label: {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: size, height: size)
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

    private func isSameColor(_ a: Color, _ b: Color) -> Bool {
        guard let ac = a.cgColorComponents,
              let bc = b.cgColorComponents else { return false }
        let threshold: CGFloat = 0.01
        return abs(ac.r - bc.r) < threshold
            && abs(ac.g - bc.g) < threshold
            && abs(ac.b - bc.b) < threshold
    }

    private func hexString(for color: Color) -> String {
        guard let c = color.cgColorComponents else { return "#000000" }
        let r = Int(c.r * 255)
        let g = Int(c.g * 255)
        let b = Int(c.b * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
