//
//  IsometricPreviewView.swift
//  VoxelSprite
//
//  Isometrische Würfel-Vorschau: Alle 6 Faces live auf dem Würfel.
//  2D-Projektion – kein echtes 3D nötig.
//  4 vordefinierte Winkel: Iso, Front, Back, Top-Down.
//

import SwiftUI

// MARK: - Vorschau-Winkel

enum PreviewAngle: String, CaseIterable, Identifiable {
    case iso     = "Iso"
    case front   = "Front"
    case back    = "Back"
    case topDown = "Top"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .iso:     return "cube"
        case .front:   return "square"
        case .back:    return "square.fill"
        case .topDown: return "arrow.down.to.line"
        }
    }
}

// MARK: - Isometric Preview View

struct IsometricPreviewView: View {

    @EnvironmentObject var blockVM: BlockViewModel

    @State private var previewAngle: PreviewAngle = .iso
    @State private var minecraftLighting: Bool = false

    /// Electric Teal
    private let teal = Color(red: 0.0, green: 0.85, blue: 0.85)

    /// Vorschau-Größe
    private let previewSize: CGFloat = 180

    /// Minecraft-Lichtmultiplikatoren
    private let lightTop: Double = 1.0
    private let lightSide: Double = 0.85
    private let lightBottom: Double = 0.70

    var body: some View {
        VStack(spacing: 8) {
            // Angle Selector + Lighting Toggle
            HStack(spacing: 4) {
                ForEach(PreviewAngle.allCases) { angle in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            previewAngle = angle
                        }
                    } label: {
                        Image(systemName: angle.iconName)
                            .font(.system(size: 10, weight: .medium))
                            .frame(width: 28, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(previewAngle == angle ? teal.opacity(0.2) : Color.clear)
                            )
                            .foregroundStyle(previewAngle == angle ? teal : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(angle.rawValue)
                }

                Spacer().frame(width: 4)

                // Minecraft Lighting Toggle
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        minecraftLighting.toggle()
                    }
                } label: {
                    Image(systemName: minecraftLighting ? "sun.max.fill" : "sun.max")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 28, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(minecraftLighting ? teal.opacity(0.2) : Color.clear)
                        )
                        .foregroundStyle(minecraftLighting ? teal : .secondary)
                }
                .buttonStyle(.plain)
                .help("Minecraft Lighting (approx.) – nur Preview")
            }

            // 3D Preview Canvas
            Canvas { context, size in
                let project = blockVM.project
                let gs = project.gridSize
                let useLighting = minecraftLighting

                switch previewAngle {
                case .iso:
                    drawIsometric(context: context, size: size, project: project, gridSize: gs, lighting: useLighting)
                case .front:
                    drawFlatFace(context: context, size: size, canvas: project.canvas(for: .north), gridSize: gs,
                                 lightMultiplier: useLighting ? lightSide : 1.0)
                case .back:
                    drawFlatFace(context: context, size: size, canvas: project.canvas(for: .south), gridSize: gs,
                                 lightMultiplier: useLighting ? lightSide : 1.0)
                case .topDown:
                    drawFlatFace(context: context, size: size, canvas: project.canvas(for: .top), gridSize: gs,
                                 lightMultiplier: useLighting ? lightTop : 1.0)
                }
            }
            .frame(width: previewSize, height: previewSize)
            .background(Color(red: 0.05, green: 0.05, blue: 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - Isometrische Projektion

    /// Zeichnet den Würfel in isometrischer Ansicht.
    /// Zeigt 3 sichtbare Faces: Top, Nord (Vorderseite), Ost (rechte Seite).
    private func drawIsometric(context: GraphicsContext, size: CGSize, project: BlockProject, gridSize: Int, lighting: Bool = false) {
        let topCanvas = project.canvas(for: .top)
        let frontCanvas = project.canvas(for: .north)
        let rightCanvas = project.canvas(for: .east)

        // Isometrische Parameter
        let cubeWidth = size.width * 0.7
        let halfW = cubeWidth / 2
        let quarterH = cubeWidth / 4

        let centerX = size.width / 2
        let centerY = size.height / 2

        // Pixel-Größe pro Face
        let pixelW = cubeWidth / CGFloat(gridSize)
        let pixelH = quarterH / CGFloat(gridSize)

        // Top Face (Raute oben)
        let topDarken = lighting ? (1.0 - lightTop) : 0.0
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                if let color = topCanvas.pixel(at: x, y: y) {
                    let isoX = centerX + (CGFloat(x) - CGFloat(y)) * (pixelW / 2)
                    let isoY = centerY - quarterH + (CGFloat(x) + CGFloat(y)) * (pixelH / 2) - quarterH

                    var path = Path()
                    path.move(to: CGPoint(x: isoX, y: isoY))
                    path.addLine(to: CGPoint(x: isoX + pixelW / 2, y: isoY + pixelH / 2))
                    path.addLine(to: CGPoint(x: isoX, y: isoY + pixelH))
                    path.addLine(to: CGPoint(x: isoX - pixelW / 2, y: isoY + pixelH / 2))
                    path.closeSubpath()

                    let drawColor = topDarken > 0 ? darken(color, by: topDarken) : color
                    context.fill(path, with: .color(drawColor))
                }
            }
        }

        // Front Face (links unten) — North
        let frontDarken = lighting ? (1.0 - lightSide) : 0.15
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                if let color = frontCanvas.pixel(at: x, y: y) {
                    let darkened = darken(color, by: frontDarken)

                    let baseX = centerX - halfW + CGFloat(x) * (pixelW / 2)
                    let baseY = centerY + CGFloat(x) * (pixelH / 2) - quarterH + CGFloat(y) * (quarterH * 2 / CGFloat(gridSize))

                    var path = Path()
                    path.move(to: CGPoint(x: baseX, y: baseY))
                    path.addLine(to: CGPoint(x: baseX + pixelW / 2, y: baseY + pixelH / 2))
                    path.addLine(to: CGPoint(x: baseX + pixelW / 2, y: baseY + pixelH / 2 + quarterH * 2 / CGFloat(gridSize)))
                    path.addLine(to: CGPoint(x: baseX, y: baseY + quarterH * 2 / CGFloat(gridSize)))
                    path.closeSubpath()

                    context.fill(path, with: .color(darkened))
                }
            }
        }

        // Right Face (rechts unten) — East
        let rightDarken = lighting ? (1.0 - lightBottom) : 0.30
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                if let color = rightCanvas.pixel(at: x, y: y) {
                    let darkened = darken(color, by: rightDarken)

                    let baseX = centerX + CGFloat(x) * (pixelW / 2)
                    let baseY = centerY + quarterH - CGFloat(x) * (pixelH / 2) - quarterH + CGFloat(y) * (quarterH * 2 / CGFloat(gridSize))

                    var path = Path()
                    path.move(to: CGPoint(x: baseX, y: baseY))
                    path.addLine(to: CGPoint(x: baseX + pixelW / 2, y: baseY - pixelH / 2))
                    path.addLine(to: CGPoint(x: baseX + pixelW / 2, y: baseY - pixelH / 2 + quarterH * 2 / CGFloat(gridSize)))
                    path.addLine(to: CGPoint(x: baseX, y: baseY + quarterH * 2 / CGFloat(gridSize)))
                    path.closeSubpath()

                    context.fill(path, with: .color(darkened))
                }
            }
        }

        // Outline
        var outline = Path()
        // Top diamond
        outline.move(to: CGPoint(x: centerX, y: centerY - quarterH * 2))
        outline.addLine(to: CGPoint(x: centerX + halfW, y: centerY - quarterH))
        outline.addLine(to: CGPoint(x: centerX + halfW, y: centerY + quarterH))
        outline.addLine(to: CGPoint(x: centerX, y: centerY + quarterH * 2))
        outline.addLine(to: CGPoint(x: centerX - halfW, y: centerY + quarterH))
        outline.addLine(to: CGPoint(x: centerX - halfW, y: centerY - quarterH))
        outline.closeSubpath()

        context.stroke(outline, with: .color(.white.opacity(0.15)), lineWidth: 0.5)
    }

    // MARK: - Flat Face View

    /// Zeichnet ein einzelnes Face als flache 2D-Vorschau
    private func drawFlatFace(context: GraphicsContext, size: CGSize, canvas: PixelCanvas, gridSize: Int, lightMultiplier: Double = 1.0) {
        let padding: CGFloat = 10
        let availableSize = min(size.width, size.height) - padding * 2
        let cellSize = availableSize / CGFloat(gridSize)
        let offsetX = (size.width - availableSize) / 2
        let offsetY = (size.height - availableSize) / 2

        // Schachbrett
        let lightColor = Color(red: 0.12, green: 0.12, blue: 0.16)
        let darkColor = Color(red: 0.09, green: 0.09, blue: 0.13)

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let bgColor = (x + y) % 2 == 0 ? lightColor : darkColor
                let rect = CGRect(
                    x: offsetX + CGFloat(x) * cellSize,
                    y: offsetY + CGFloat(y) * cellSize,
                    width: cellSize,
                    height: cellSize
                )
                context.fill(Path(rect), with: .color(bgColor))

                if let color = canvas.pixel(at: x, y: y) {
                    let drawColor = lightMultiplier < 1.0 ? darken(color, by: 1.0 - lightMultiplier) : color
                    context.fill(Path(rect), with: .color(drawColor))
                }
            }
        }
    }

    // MARK: - Hilfsfunktionen

    /// sRGB → Linear
    private func sRGBToLinear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// Linear → sRGB
    private func linearToSRGB(_ c: Double) -> Double {
        c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1.0 / 2.4) - 0.055
    }

    /// Dunkelt eine Farbe ab (für 3D-Effekt auf Seitenflächen).
    /// Berechnung in linearem Farbraum für gamma-korrekte Ergebnisse.
    private func darken(_ color: Color, by amount: Double) -> Color {
        guard let c = color.cgColorComponents else { return color }
        let multiplier = max(0, 1.0 - amount)
        // In linear space multiplizieren, dann zurück in sRGB
        let r = linearToSRGB(sRGBToLinear(c.r) * multiplier)
        let g = linearToSRGB(sRGBToLinear(c.g) * multiplier)
        let b = linearToSRGB(sRGBToLinear(c.b) * multiplier)
        return Color(
            red: max(0, min(1, r)),
            green: max(0, min(1, g)),
            blue: max(0, min(1, b)),
            opacity: c.a
        )
    }
}

// MARK: - Tile Preview

/// 3×3 gekachelte Vorschau für nahtlose Texturen
struct TilePreviewView: View {

    @EnvironmentObject var blockVM: BlockViewModel

    /// Welches Face gekachelt anzeigen
    var faceType: FaceType = .north

    private let tileCount = 3
    private let previewSize: CGFloat = 150

    var body: some View {
        let canvas = blockVM.project.canvas(for: faceType)
        let gs = blockVM.project.gridSize

        Canvas { context, size in
            let tileSize = size.width / CGFloat(tileCount)
            let cellSize = tileSize / CGFloat(gs)

            for tileY in 0..<tileCount {
                for tileX in 0..<tileCount {
                    let offsetX = CGFloat(tileX) * tileSize
                    let offsetY = CGFloat(tileY) * tileSize

                    for y in 0..<gs {
                        for x in 0..<gs {
                            if let color = canvas.pixel(at: x, y: y) {
                                let rect = CGRect(
                                    x: offsetX + CGFloat(x) * cellSize,
                                    y: offsetY + CGFloat(y) * cellSize,
                                    width: cellSize + 0.5, // Overlap to prevent gaps
                                    height: cellSize + 0.5
                                )
                                context.fill(Path(rect), with: .color(color))
                            }
                        }
                    }
                }
            }

            // Tile Grid Lines
            let lineColor = Color.white.opacity(0.1)
            for i in 0...tileCount {
                let pos = CGFloat(i) * tileSize

                var vPath = Path()
                vPath.move(to: CGPoint(x: pos, y: 0))
                vPath.addLine(to: CGPoint(x: pos, y: size.height))
                context.stroke(vPath, with: .color(lineColor), lineWidth: 0.5)

                var hPath = Path()
                hPath.move(to: CGPoint(x: 0, y: pos))
                hPath.addLine(to: CGPoint(x: size.width, y: pos))
                context.stroke(hPath, with: .color(lineColor), lineWidth: 0.5)
            }
        }
        .frame(width: previewSize, height: previewSize)
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}
