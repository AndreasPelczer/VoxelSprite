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

    // MARK: - PNG Import

    /// Erzeugt ein PixelCanvas aus einem CGImage.
    /// Skaliert das Bild auf die Zielgröße falls angegeben, sonst nutzt die Originalgröße.
    static func fromCGImage(_ cgImage: CGImage, targetWidth: Int? = nil, targetHeight: Int? = nil) -> PixelCanvas? {
        let w = targetWidth ?? cgImage.width
        let h = targetHeight ?? cgImage.height
        guard w > 0, w <= 128, h > 0, h <= 128 else { return nil }

        // Bild auf Zielgröße rendern
        guard let context = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        guard let data = context.data else { return nil }
        let ptr = data.bindMemory(to: UInt8.self, capacity: w * h * 4)

        var canvas = PixelCanvas(width: w, height: h)
        for y in 0..<h {
            for x in 0..<w {
                // CGContext hat Y=0 unten, Canvas hat Y=0 oben
                let flippedY = h - 1 - y
                let offset = (flippedY * w + x) * 4
                let r = ptr[offset]
                let g = ptr[offset + 1]
                let b = ptr[offset + 2]
                let a = ptr[offset + 3]

                if a > 0 {
                    canvas.setPixel(at: x, y: y, color: Color(
                        red: Double(r) / 255.0,
                        green: Double(g) / 255.0,
                        blue: Double(b) / 255.0,
                        opacity: Double(a) / 255.0
                    ))
                }
            }
        }
        return canvas
    }

    // MARK: - Canvas-Transformationen

    /// Horizontal spiegeln (links ↔ rechts)
    func mirroredHorizontal() -> PixelCanvas {
        var result = PixelCanvas(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                result.pixels[y][width - 1 - x] = pixels[y][x]
            }
        }
        return result
    }

    /// Vertikal spiegeln (oben ↔ unten)
    func mirroredVertical() -> PixelCanvas {
        var result = PixelCanvas(width: width, height: height)
        for y in 0..<height {
            result.pixels[height - 1 - y] = pixels[y]
        }
        return result
    }

    /// 90° im Uhrzeigersinn drehen
    func rotatedCW() -> PixelCanvas {
        var result = PixelCanvas(width: height, height: width)
        for y in 0..<height {
            for x in 0..<width {
                result.pixels[x][height - 1 - y] = pixels[y][x]
            }
        }
        return result
    }
}
