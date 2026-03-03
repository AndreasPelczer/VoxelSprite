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

    /// Electric Teal
    private let teal = Color(red: 0.0, green: 0.85, blue: 0.85)

    /// Vorschau-Größe
    private let previewSize: CGFloat = 180

    var body: some View {
        VStack(spacing: 8) {
            // Angle Selector
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
            }

            // 3D Preview Canvas
            Canvas { context, size in
                let project = blockVM.project
                let gs = project.gridSize

                switch previewAngle {
                case .iso:
                    drawIsometric(context: context, size: size, project: project, gridSize: gs)
                case .front:
                    drawFlatFace(context: context, size: size, canvas: project.canvas(for: .north), gridSize: gs)
                case .back:
                    drawFlatFace(context: context, size: size, canvas: project.canvas(for: .south), gridSize: gs)
                case .topDown:
                    drawFlatFace(context: context, size: size, canvas: project.canvas(for: .top), gridSize: gs)
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
    private func drawIsometric(context: GraphicsContext, size: CGSize, project: BlockProject, gridSize: Int) {
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

                    context.fill(path, with: .color(color))
                }
            }
        }

        // Front Face (links unten) — North
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                if let color = frontCanvas.pixel(at: x, y: y) {
                    // Leicht abgedunkelt für 3D-Effekt
                    let darkened = darken(color, by: 0.15)

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
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                if let color = rightCanvas.pixel(at: x, y: y) {
                    // Stärker abgedunkelt
                    let darkened = darken(color, by: 0.30)

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
    private func drawFlatFace(context: GraphicsContext, size: CGSize, canvas: PixelCanvas, gridSize: Int) {
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
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
    }

    // MARK: - Hilfsfunktionen

    /// Dunkelt eine Farbe ab (für 3D-Effekt auf Seitenflächen)
    private func darken(_ color: Color, by amount: Double) -> Color {
        guard let c = color.cgColorComponents else { return color }
        return Color(
            red: max(0, c.r - amount),
            green: max(0, c.g - amount),
            blue: max(0, c.b - amount),
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
