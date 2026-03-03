//
//  PixelCanvas.swift
//  VoxelSprite
//
//  Ein Pixel-Raster mit variabler Größe.
//  Unterstützt quadratische (16×16) und rechteckige Canvases (z.B. 8×12 für Steve-Faces).
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

    let width: Int
    let height: Int
    var pixels: [[Color?]]

    /// Abwärtskompatibel: gibt width zurück (für quadratische Canvases)
    var gridSize: Int { width }

    // MARK: - Init

    /// Quadratisches Canvas (bestehende API)
    init(gridSize: Int = defaultGridSize) {
        self.init(width: gridSize, height: gridSize)
    }

    /// Rechteckiges Canvas (für Steve-Faces wie 8×12)
    init(width: Int, height: Int) {
        self.width = max(1, min(128, width))
        self.height = max(1, min(128, height))
        pixels = Array(
            repeating: Array(repeating: nil as Color?, count: self.width),
            count: self.height
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
            repeating: Array(repeating: nil as Color?, count: width),
            count: height
        )
    }

    // MARK: - Validierung

    func isValid(x: Int, y: Int) -> Bool {
        x >= 0 && x < width && y >= 0 && y < height
    }

    // MARK: - Rendering

    /// Rendert das Canvas als CGImage (für SceneKit-Texturen und Export)
    /// `showGrid`: Zeichnet Pixel-Rasterlinien ins Bild (für 3D-Vorschau)
    func toCGImage(transparentBackground: Bool = true, showGrid: Bool = false) -> CGImage? {
        // Hochskalieren wenn Grid aktiv, damit Linien sichtbar sind
        let scale = showGrid ? max(8, 256 / max(width, height)) : 1
        let imgW = width * scale
        let imgH = height * scale

        guard let context = CGContext(
            data: nil,
            width: imgW,
            height: imgH,
            bitsPerComponent: 8,
            bytesPerRow: imgW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        if !transparentBackground {
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: imgW, height: imgH))
        }

        // Pixel zeichnen
        for y in 0..<height {
            for x in 0..<width {
                if let color = pixel(at: x, y: y),
                   let c = color.cgColorComponents {
                    context.setFillColor(red: c.r, green: c.g, blue: c.b, alpha: c.a)
                    context.fill(CGRect(
                        x: x * scale,
                        y: (height - 1 - y) * scale,
                        width: scale,
                        height: scale
                    ))
                }
            }
        }

        // Grid-Linien zeichnen
        if showGrid {
            context.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.25)
            context.setLineWidth(max(1, CGFloat(scale) / 10.0))

            // Vertikale Linien
            for i in 0...width {
                context.move(to: CGPoint(x: CGFloat(i * scale), y: 0))
                context.addLine(to: CGPoint(x: CGFloat(i * scale), y: CGFloat(imgH)))
            }
            // Horizontale Linien
            for i in 0...height {
                context.move(to: CGPoint(x: 0, y: CGFloat(i * scale)))
                context.addLine(to: CGPoint(x: CGFloat(imgW), y: CGFloat(i * scale)))
            }
            context.strokePath()
        }

        return context.makeImage()
    }
}
