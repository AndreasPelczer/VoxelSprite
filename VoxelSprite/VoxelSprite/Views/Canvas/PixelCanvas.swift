//
//  PixelCanvas.swift
//  VoxelSprite
//
//  Ein Pixel-Raster mit variabler Größe.
//  Standard: 16×16 für Minecraft-Texturen.
//

import SwiftUI

struct PixelCanvas {

    // MARK: - Vordefinierte Größen

    enum PresetSize: Int, CaseIterable, Identifiable {
        case standard = 16
        case double   = 32
        case quad     = 64

        var id: Int { rawValue }

        var label: String {
            "\(rawValue)×\(rawValue)"
        }
    }

    /// Standard-Größe für Minecraft-Texturen
    static let defaultGridSize = 16

    // MARK: - Daten

    let gridSize: Int
    var pixels: [[Color?]]

    // MARK: - Init

    init(gridSize: Int = defaultGridSize) {
        self.gridSize = max(1, min(128, gridSize))
        pixels = Array(
            repeating: Array(repeating: nil as Color?, count: self.gridSize),
            count: self.gridSize
        )
    }

    // MARK: - Zugriff

    func pixel(at x: Int, y: Int) -> Color? {
        guard isValid(x: x, y: y) else { return nil }
        return pixels[y][x]
    }

    mutating func setPixel(at x: Int, y: Int, color: Color?) {
        guard isValid(x: x, y: y) else { return }
        pixels[y][x] = color
    }

    mutating func clear() {
        pixels = Array(
            repeating: Array(repeating: nil as Color?, count: gridSize),
            count: gridSize
        )
    }

    // MARK: - Validierung

    func isValid(x: Int, y: Int) -> Bool {
        x >= 0 && x < gridSize && y >= 0 && y < gridSize
    }
}
