//
//  PixelCanvas.swift
//  PlanktonSpriteApp
//
//  Created by Andreas Pelczer on 27.02.26.
//


import SwiftUI

/// Ein Pixel-Raster mit variabler Größe.
/// Unterstützt 16×16, 32×32, 64×64 und Custom-Größen.
/// Jeder Pixel ist entweder eine Farbe oder nil (transparent).
struct PixelCanvas {

    // MARK: - Vordefinierte Größen

    /// Standard-Größen für Canvas
    enum PresetSize: Int, CaseIterable, Identifiable {
        case small = 16
        case medium = 32
        case large = 64

        var id: Int { rawValue }

        var label: String {
            "\(rawValue)×\(rawValue)"
        }
    }

    /// Default-Größe – rückwärtskompatibel
    static let defaultGridSize = 32

    // MARK: - Daten

    /// Größe des Rasters (Breite = Höhe)
    let gridSize: Int

    /// 2D-Array: pixels[y][x] – Zeile zuerst, dann Spalte.
    /// nil bedeutet: dieser Pixel ist transparent.
    var pixels: [[Color?]]

    // MARK: - Init

    /// Erzeugt ein leeres Canvas mit der angegebenen Größe
    init(gridSize: Int = defaultGridSize) {
        self.gridSize = max(1, min(128, gridSize))
        pixels = Array(
            repeating: Array(repeating: nil as Color?, count: self.gridSize),
            count: self.gridSize
        )
    }

    // MARK: - Zugriff

    /// Sicherer Zugriff auf einen Pixel.
    /// Gibt nil zurück wenn x/y außerhalb des Rasters liegen.
    func pixel(at x: Int, y: Int) -> Color? {
        guard isValid(x: x, y: y) else { return nil }
        return pixels[y][x]
    }

    /// Setzt einen Pixel auf eine Farbe (oder nil zum Löschen).
    /// Ignoriert ungültige Koordinaten still – kein Crash.
    mutating func setPixel(at x: Int, y: Int, color: Color?) {
        guard isValid(x: x, y: y) else { return }
        pixels[y][x] = color
    }

    /// Löscht das komplette Canvas – alles wieder transparent
    mutating func clear() {
        pixels = Array(
            repeating: Array(repeating: nil as Color?, count: gridSize),
            count: gridSize
        )
    }

    // MARK: - Validierung

    /// Prüft ob Koordinaten innerhalb des Rasters liegen
    func isValid(x: Int, y: Int) -> Bool {
        x >= 0 && x < gridSize && y >= 0 && y < gridSize
    }
}