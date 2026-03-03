//
//  PixelCanvasView.swift
//  VoxelSprite
//
//  Das Pixel-Raster zum Zeichnen.
//  Unterstützt quadratische und rechteckige Canvases (für Steve-Faces).
//  Bezieht Canvas-Daten über CanvasViewModel (modus-unabhängig).
//

import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

struct PixelCanvasView: View {

    @EnvironmentObject var canvasVM: CanvasViewModel

    @State private var hoveredPixel: (x: Int, y: Int)?
    @State private var isDrawing: Bool = false

    // MARK: - Dynamische Größen

    private var canvasWidth: Int {
        canvasVM.canvasWidth
    }

    private var canvasHeight: Int {
        canvasVM.canvasHeight
    }

    private var baseCellSize: CGFloat {
        let maxDim = max(canvasWidth, canvasHeight)
        switch maxDim {
        case 1...8:   return 32
        case 9...16:  return 20
        case 17...32: return 14
        case 33...64: return 7
        default:      return max(4, 448.0 / CGFloat(maxDim))
        }
    }

    private var cellSize: CGFloat {
        baseCellSize * canvasVM.zoomScale
    }

    private var totalWidth: CGFloat {
        CGFloat(canvasWidth) * cellSize
    }

    private var totalHeight: CGFloat {
        CGFloat(canvasHeight) * cellSize
    }

    // MARK: - Body

    var body: some View {
        let canvas = canvasVM.currentCanvas
        let gridAccessor: (Int, Int) -> Color? = { x, y in
            canvas.pixel(at: x, y: y)
        }
        let showGrid = canvasVM.showGrid
        let hover = hoveredPixel
        let isPenTool = canvasVM.currentTool == .pen || canvasVM.currentTool == .line || canvasVM.currentTool == .rectangle
        let currentColor = canvasVM.currentColor
        let cw = canvasWidth
        let ch = canvasHeight
        let cs = cellSize

        // Face Overlay
        let overlayCanvas = canvasVM.overlayCanvas
        let overlayOpacity = canvasVM.faceOverlayOpacity

        Canvas { context, _ in

            // 1. Schachbrett-Hintergrund
            drawCheckerboard(context: context, width: cw, height: ch, cellSize: cs)

            // 2. Face / Layer Overlay
            if let overlay = overlayCanvas {
                drawOverlay(context: context, canvas: overlay, width: cw, height: ch, cellSize: cs, opacity: overlayOpacity)
            }

            // 3. Pixel zeichnen
            drawPixels(context: context, width: cw, height: ch, cellSize: cs, accessor: gridAccessor)

            // 4. Rasterlinien
            if showGrid {
                drawGridLines(context: context, width: cw, height: ch, cellSize: cs)
            }

            // 5. Hover-Highlight
            if let hover = hover {
                drawHoverIndicator(context: context, x: hover.x, y: hover.y, isPen: isPenTool, color: currentColor, cellSize: cs)
            }
        }
        .frame(width: totalWidth, height: totalHeight)
        .gesture(drawingGesture)
        #if os(macOS)
        .onHover { isHovering in
            if !isHovering { hoveredPixel = nil }
        }
        #endif
        #if os(macOS)
        .background(
            MouseTrackingView { location in
                let (x, y) = pixelCoordinate(from: location)
                if canvasVM.currentCanvas.isValid(x: x, y: y) {
                    hoveredPixel = (x, y)
                }
            } onExit: {
                hoveredPixel = nil
            }
        )
        #endif
        .border(Color.gray.opacity(0.3), width: 1)
        #if canImport(AppKit)
        .onHover { inside in
            if inside {
                NSCursor.crosshair.push()
            } else {
                NSCursor.pop()
            }
        }
        #endif
    }

    // MARK: - Zeichengesture

    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let (x, y) = pixelCoordinate(from: value.location)
                guard canvasVM.currentCanvas.isValid(x: x, y: y) else { return }

                if !isDrawing {
                    isDrawing = true
                    canvasVM.beginStroke(at: x, y: y)
                } else {
                    canvasVM.continueStroke(at: x, y: y)
                }
            }
            .onEnded { value in
                let (x, y) = pixelCoordinate(from: value.location)
                canvasVM.endStroke(at: x, y: y)
                isDrawing = false
            }
    }

    // MARK: - Koordinaten-Umrechnung

    private func pixelCoordinate(from point: CGPoint) -> (Int, Int) {
        let x = Int(point.x / cellSize)
        let y = Int(point.y / cellSize)
        return (
            max(0, min(canvasWidth - 1, x)),
            max(0, min(canvasHeight - 1, y))
        )
    }

    // MARK: - Canvas-Zeichenfunktionen

    private func drawCheckerboard(context: GraphicsContext, width: Int, height: Int, cellSize: CGFloat) {
        let lightColor = Color(red: 0.18, green: 0.18, blue: 0.22)
        let darkColor = Color(red: 0.15, green: 0.15, blue: 0.20)

        for y in 0..<height {
            for x in 0..<width {
                let color = (x + y) % 2 == 0 ? lightColor : darkColor
                let rect = CGRect(
                    x: CGFloat(x) * cellSize,
                    y: CGFloat(y) * cellSize,
                    width: cellSize,
                    height: cellSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
    }

    private func drawPixels(context: GraphicsContext, width: Int, height: Int, cellSize: CGFloat, accessor: (Int, Int) -> Color?) {
        for y in 0..<height {
            for x in 0..<width {
                if let color = accessor(x, y) {
                    let rect = CGRect(
                        x: CGFloat(x) * cellSize,
                        y: CGFloat(y) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
    }

    /// Zeichnet ein halbtransparentes Overlay eines anderen Faces / Layers
    private func drawOverlay(context: GraphicsContext, canvas: PixelCanvas, width: Int, height: Int, cellSize: CGFloat, opacity: Double) {
        var overlayContext = context
        overlayContext.opacity = opacity
        let drawW = min(width, canvas.width)
        let drawH = min(height, canvas.height)
        for y in 0..<drawH {
            for x in 0..<drawW {
                if let color = canvas.pixel(at: x, y: y) {
                    let rect = CGRect(
                        x: CGFloat(x) * cellSize,
                        y: CGFloat(y) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    overlayContext.fill(Path(rect), with: .color(color))
                }
            }
        }
    }

    private func drawGridLines(context: GraphicsContext, width: Int, height: Int, cellSize: CGFloat) {
        let lineColor = Color.white.opacity(0.08)

        for i in 0...width {
            let pos = CGFloat(i) * cellSize

            var vPath = Path()
            vPath.move(to: CGPoint(x: pos, y: 0))
            vPath.addLine(to: CGPoint(x: pos, y: CGFloat(height) * cellSize))
            context.stroke(vPath, with: .color(lineColor), lineWidth: 0.5)
        }

        for i in 0...height {
            let pos = CGFloat(i) * cellSize

            var hPath = Path()
            hPath.move(to: CGPoint(x: 0, y: pos))
            hPath.addLine(to: CGPoint(x: CGFloat(width) * cellSize, y: pos))
            context.stroke(hPath, with: .color(lineColor), lineWidth: 0.5)
        }
    }

    private func drawHoverIndicator(context: GraphicsContext, x: Int, y: Int, isPen: Bool, color: Color, cellSize: CGFloat) {
        let rect = CGRect(
            x: CGFloat(x) * cellSize,
            y: CGFloat(y) * cellSize,
            width: cellSize,
            height: cellSize
        )

        context.stroke(
            Path(rect),
            with: .color(.white.opacity(0.5)),
            lineWidth: 1.5
        )

        if isPen {
            context.fill(
                Path(rect),
                with: .color(color.opacity(0.3))
            )
        }
    }
}

#if os(macOS)
import AppKit
private struct MouseTrackingView: NSViewRepresentable {
    var onMove: (CGPoint) -> Void
    var onExit: () -> Void

    init(_ onMove: @escaping (CGPoint) -> Void, onExit: @escaping () -> Void) {
        self.onMove = onMove
        self.onExit = onExit
    }

    func makeNSView(context: Context) -> TrackingNSView {
        let v = TrackingNSView()
        v.onMove = onMove
        v.onExit = onExit
        return v
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onMove = onMove
        nsView.onExit = onExit
    }

    final class TrackingNSView: NSView {
        var onMove: ((CGPoint) -> Void)?
        var onExit: (() -> Void)?
        private var trackingArea: NSTrackingArea?

        override var isFlipped: Bool { true }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let area = trackingArea { removeTrackingArea(area) }
            let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
            let area = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseMoved(with event: NSEvent) {
            super.mouseMoved(with: event)
            let loc = convert(event.locationInWindow, from: nil)
            onMove?(CGPoint(x: max(0, loc.x), y: max(0, loc.y)))
        }

        override func mouseEntered(with event: NSEvent) {
            super.mouseEntered(with: event)
            let loc = convert(event.locationInWindow, from: nil)
            onMove?(CGPoint(x: max(0, loc.x), y: max(0, loc.y)))
        }

        override func mouseExited(with event: NSEvent) {
            super.mouseExited(with: event)
            onExit?()
        }
    }
}
#endif
