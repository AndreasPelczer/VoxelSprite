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
    /// `nearestNeighbor`: true = pixel-scharfe Skalierung (für Pixel Art), false = bilineare Glättung
    static func fromCGImage(_ cgImage: CGImage, targetWidth: Int? = nil, targetHeight: Int? = nil, nearestNeighbor: Bool = true) -> PixelCanvas? {
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

        context.interpolationQuality = nearestNeighbor ? .none : .medium
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

    // MARK: - Tile-Seamless Prüfung

    struct TileCheckResult {
        var horizontalMismatches: [(x: Int, y: Int)] = []
        var verticalMismatches: [(x: Int, y: Int)] = []
        var isSeamless: Bool { horizontalMismatches.isEmpty && verticalMismatches.isEmpty }
    }

    /// Prüft ob die Textur nahtlos kachelt.
    /// Vergleicht linke ↔ rechte und obere ↔ untere Kante.
    /// `tolerant`: true = ΔRGBA ≤ 0.02, false = exakte Übereinstimmung
    func checkTileSeamless(tolerant: Bool = false) -> TileCheckResult {
        var result = TileCheckResult()

        for y in 0..<height {
            let leftColor = pixel(at: 0, y: y)
            let rightColor = pixel(at: width - 1, y: y)
            if !colorsMatch(leftColor, rightColor, tolerant: tolerant) {
                result.horizontalMismatches.append((x: 0, y: y))
            }
        }

        for x in 0..<width {
            let topColor = pixel(at: x, y: 0)
            let bottomColor = pixel(at: x, y: height - 1)
            if !colorsMatch(topColor, bottomColor, tolerant: tolerant) {
                result.verticalMismatches.append((x: x, y: 0))
            }
        }

        return result
    }

    private func colorsMatch(_ a: Color?, _ b: Color?, tolerant: Bool) -> Bool {
        if a == nil && b == nil { return true }
        guard let a = a, let b = b,
              let ca = a.cgColorComponents, let cb = b.cgColorComponents else { return false }
        if !tolerant {
            // Exakter Vergleich (premultiplied-sicher: Alpha muss identisch sein)
            return ca.r == cb.r && ca.g == cb.g && ca.b == cb.b && ca.a == cb.a
        }
        let t: CGFloat = 0.02
        return abs(ca.r - cb.r) < t && abs(ca.g - cb.g) < t
            && abs(ca.b - cb.b) < t && abs(ca.a - cb.a) < t
    }

    // MARK: - Palette Reduce

    /// sRGB → Linear Konvertierung
    private static func sRGBToLinear(_ c: CGFloat) -> CGFloat {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// Linear → sRGB Konvertierung
    private static func linearToSRGB(_ c: CGFloat) -> CGFloat {
        c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1.0 / 2.4) - 0.055
    }

    /// Reduziert alle Farben auf die nächste Farbe aus der Palette.
    /// Optional mit Floyd-Steinberg Dithering.
    /// Transparente Pixel bleiben transparent.
    /// Distanz-Berechnung in linearem RGB für visuell korrekte Ergebnisse.
    func reducedToPalette(_ palette: [Color], dithering: Bool = false) -> PixelCanvas {
        let pc: [(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)] = palette.compactMap {
            $0.cgColorComponents
        }
        guard !pc.isEmpty else { return self }

        // Palette in linearem RGB vorberechnen
        let linearPC = pc.map { (r: Self.sRGBToLinear($0.r), g: Self.sRGBToLinear($0.g), b: Self.sRGBToLinear($0.b)) }

        var result = PixelCanvas(width: width, height: height)

        var errR = Array(repeating: Array(repeating: CGFloat(0), count: width + 2), count: height + 1)
        var errG = errR, errB = errR

        for y in 0..<height {
            for x in 0..<width {
                guard let color = pixel(at: x, y: y),
                      let c = color.cgColorComponents else { continue }

                // Fast transparente Pixel überspringen (Alpha < 1%)
                if c.a < 0.01 { continue }

                // In linearen Farbraum konvertieren
                var r = Self.sRGBToLinear(c.r)
                var g = Self.sRGBToLinear(c.g)
                var b = Self.sRGBToLinear(c.b)

                if dithering {
                    r = max(0, min(1, r + errR[y][x + 1]))
                    g = max(0, min(1, g + errG[y][x + 1]))
                    b = max(0, min(1, b + errB[y][x + 1]))
                }

                // Nächste Farbe finden (euklidische Distanz in linearem RGB)
                var bestDist: CGFloat = .infinity
                var bestIdx = 0
                for (i, lp) in linearPC.enumerated() {
                    let d = (r - lp.r) * (r - lp.r) + (g - lp.g) * (g - lp.g) + (b - lp.b) * (b - lp.b)
                    if d < bestDist { bestDist = d; bestIdx = i }
                }

                let n = pc[bestIdx]
                let nLin = linearPC[bestIdx]
                // Ergebnis zurück in sRGB, Alpha beibehalten
                result.setPixel(at: x, y: y, color: Color(red: n.r, green: n.g, blue: n.b, opacity: c.a))

                if dithering {
                    let eR = r - nLin.r, eG = g - nLin.g, eB = b - nLin.b
                    // Floyd-Steinberg Distribution: 7/16, 3/16, 5/16, 1/16
                    errR[y][x + 2]     += eR * 7/16; errR[y + 1][x] += eR * 3/16
                    errR[y + 1][x + 1] += eR * 5/16; errR[y + 1][x + 2] += eR * 1/16
                    errG[y][x + 2]     += eG * 7/16; errG[y + 1][x] += eG * 3/16
                    errG[y + 1][x + 1] += eG * 5/16; errG[y + 1][x + 2] += eG * 1/16
                    errB[y][x + 2]     += eB * 7/16; errB[y + 1][x] += eB * 3/16
                    errB[y + 1][x + 1] += eB * 5/16; errB[y + 1][x + 2] += eB * 1/16
                }
            }
        }
        return result
    }
}
