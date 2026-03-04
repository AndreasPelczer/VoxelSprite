//
//  CanvasViewModel.swift
//  VoxelSprite
//
//  Steuert alles rund ums Zeichnen auf dem Canvas.
//  Unterstützt Block-Modus, Item-Modus und Skin-Modus.
//

import SwiftUI
import Combine

class CanvasViewModel: ObservableObject {

    // MARK: - Editor-Modus

    enum EditorMode: String, CaseIterable, Identifiable {
        case block    = "Block"
        case item     = "Item"
        case skin     = "Steve"
        case painting = "Painting"
        case recipe   = "Rezept"
        case entity   = "Entity"
        case armor    = "Armor"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .block:    return "cube"
            case .item:     return "shield"
            case .skin:     return "figure.stand"
            case .painting: return "photo.artframe"
            case .recipe:   return "square.grid.3x3"
            case .entity:   return "hare"
            case .armor:    return "shield.lefthalf.filled"
            }
        }
    }

    // MARK: - Werkzeuge

    enum Tool: String, CaseIterable {
        case pen        = "Stift"
        case eraser     = "Radierer"
        case fill       = "Füllen"
        case line       = "Linie"
        case rectangle  = "Rechteck"
        case eyedropper = "Pipette"

        var iconName: String {
            switch self {
            case .pen:        return "pencil"
            case .eraser:     return "eraser"
            case .fill:       return "drop.fill"
            case .line:       return "line.diagonal"
            case .rectangle:  return "rectangle"
            case .eyedropper: return "eyedropper"
            }
        }
    }

    // MARK: - Published State

    @Published var editorMode: EditorMode = .block
    @Published var currentTool: Tool = .pen
    @Published var currentColor: Color = .cyan
    @Published var showGrid: Bool = true
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    // MARK: - Face Overlay (Block) / Layer Overlay (Skin)

    @Published var faceOverlayEnabled: Bool = false
    @Published var overlayFaceType: FaceType?
    @Published var faceOverlayOpacity: Double = 0.3

    // MARK: - Wrap Painting (Tile-Modus)

    /// Wenn aktiv, wrappen Zeichenoperationen über Canvas-Kanten
    @Published var wrapPaintingEnabled: Bool = false

    // MARK: - Tile Check

    /// Ergebnis der letzten Tile-Seamless-Prüfung
    @Published var tileCheckResult: PixelCanvas.TileCheckResult?

    /// Toleranter Vergleich: ΔRGBA ≤ 2 statt exakt
    @Published var tileCheckTolerant: Bool = false

    // MARK: - Zoom

    @Published var zoomScale: CGFloat = 1.0
    let minZoom: CGFloat = 0.5
    let maxZoom: CGFloat = 4.0

    // MARK: - Line/Shape Tool State

    @Published var shapeStartPoint: (x: Int, y: Int)?
    private var preShapeCanvas: PixelCanvas?

    // MARK: - Undo/Redo Stacks

    private var undoStack: [PixelCanvas] = []
    private var redoStack: [PixelCanvas] = []
    var maxUndoSteps = 50

    // MARK: - Referenzen

    private weak var blockViewModel: BlockViewModel?
    private weak var itemViewModel: ItemViewModel?
    private weak var skinViewModel: SkinViewModel?
    private weak var paintingViewModel: PaintingViewModel?
    private weak var entityViewModel: EntityViewModel?
    private weak var armorViewModel: ArmorViewModel?

    // MARK: - Init

    init() {}

    func connect(to blockViewModel: BlockViewModel) {
        self.blockViewModel = blockViewModel
    }

    func connect(to itemViewModel: ItemViewModel) {
        self.itemViewModel = itemViewModel
    }

    func connect(to skinViewModel: SkinViewModel) {
        self.skinViewModel = skinViewModel
    }

    func connect(to paintingViewModel: PaintingViewModel) {
        self.paintingViewModel = paintingViewModel
    }

    func connect(to entityViewModel: EntityViewModel) {
        self.entityViewModel = entityViewModel
    }

    func connect(to armorViewModel: ArmorViewModel) {
        self.armorViewModel = armorViewModel
    }

    // MARK: - Aktuelles Canvas (modus-abhängig)

    var currentCanvas: PixelCanvas {
        switch editorMode {
        case .block:
            return blockViewModel?.activeCanvas ?? PixelCanvas(gridSize: 16)
        case .item:
            return itemViewModel?.activeCanvas ?? PixelCanvas(gridSize: 16)
        case .skin:
            return skinViewModel?.activeCanvas ?? PixelCanvas(width: 8, height: 8)
        case .painting:
            return paintingViewModel?.activeCanvas ?? PixelCanvas(width: 32, height: 32)
        case .recipe:
            return PixelCanvas(gridSize: 16) // Recipe-Modus hat kein Canvas
        case .entity:
            return entityViewModel?.activeCanvas ?? PixelCanvas(width: 8, height: 8)
        case .armor:
            return armorViewModel?.activeCanvas ?? PixelCanvas(width: 8, height: 8)
        }
    }

    /// Canvas-Breite
    var canvasWidth: Int { currentCanvas.width }

    /// Canvas-Höhe
    var canvasHeight: Int { currentCanvas.height }

    private func updateCurrentCanvas(_ canvas: PixelCanvas) {
        switch editorMode {
        case .block:
            blockViewModel?.updateActiveCanvas(canvas)
        case .item:
            itemViewModel?.updateActiveCanvas(canvas)
        case .skin:
            skinViewModel?.updateActiveCanvas(canvas)
        case .painting:
            paintingViewModel?.updateActiveCanvas(canvas)
        case .recipe:
            break
        case .entity:
            entityViewModel?.updateActiveCanvas(canvas)
        case .armor:
            armorViewModel?.updateActiveCanvas(canvas)
        }
    }

    private func applyCurrentTemplate() {
        switch editorMode {
        case .block:
            blockViewModel?.applyTemplate()
            blockViewModel?.scheduleStrokeAutosave()
        case .item:
            itemViewModel?.applyTemplate()
            itemViewModel?.scheduleStrokeAutosave()
        case .skin:
            skinViewModel?.applyTemplate()
            skinViewModel?.scheduleStrokeAutosave()
        case .painting:
            paintingViewModel?.applyTemplate()
            paintingViewModel?.scheduleStrokeAutosave()
        case .recipe:
            break
        case .entity:
            entityViewModel?.applyTemplate()
            entityViewModel?.scheduleStrokeAutosave()
        case .armor:
            armorViewModel?.applyTemplate()
            armorViewModel?.scheduleStrokeAutosave()
        }
    }

    // MARK: - Face Overlay Helpers

    /// Das gegenüberliegende Face für automatisches Overlay (nur Block-Modus)
    var oppositeFaceType: FaceType? {
        guard editorMode == .block, let blockVM = blockViewModel else { return nil }
        switch blockVM.activeFaceType {
        case .top:    return .bottom
        case .bottom: return .top
        case .north:  return .south
        case .south:  return .north
        case .east:   return .west
        case .west:   return .east
        }
    }

    /// Canvas des Overlay-Faces (Block), anderer Layer (Item/Skin)
    var overlayCanvas: PixelCanvas? {
        guard faceOverlayEnabled else { return nil }

        switch editorMode {
        case .block:
            guard let blockVM = blockViewModel else { return nil }
            let faceType = overlayFaceType ?? oppositeFaceType ?? .north
            return blockVM.project.canvas(for: faceType)
        case .item:
            return itemViewModel?.overlayCanvas()
        case .skin:
            return skinViewModel?.overlayCanvas()
        case .painting, .recipe, .entity, .armor:
            return nil
        }
    }

    // MARK: - Zeichenoperationen

    func beginStroke(at x: Int, y: Int) {
        saveUndoState()

        switch currentTool {
        case .line, .rectangle:
            shapeStartPoint = (x, y)
            preShapeCanvas = currentCanvas
        default:
            applyTool(at: x, y: y)
        }
    }

    func continueStroke(at x: Int, y: Int) {
        switch currentTool {
        case .line:
            guard let start = shapeStartPoint, var canvas = preShapeCanvas else { return }
            drawLine(canvas: &canvas, x0: start.x, y0: start.y, x1: x, y1: y, color: currentColor)
            if wrapPaintingEnabled { applyEdgeWrapping(canvas: &canvas) }
            updateCurrentCanvas(canvas)
        case .rectangle:
            guard let start = shapeStartPoint, var canvas = preShapeCanvas else { return }
            drawRectangle(canvas: &canvas, x0: start.x, y0: start.y, x1: x, y1: y, color: currentColor)
            if wrapPaintingEnabled { applyEdgeWrapping(canvas: &canvas) }
            updateCurrentCanvas(canvas)
        default:
            applyTool(at: x, y: y)
        }
    }

    func endStroke(at x: Int, y: Int) {
        switch currentTool {
        case .line:
            guard let start = shapeStartPoint, var canvas = preShapeCanvas else { return }
            drawLine(canvas: &canvas, x0: start.x, y0: start.y, x1: x, y1: y, color: currentColor)
            if wrapPaintingEnabled { applyEdgeWrapping(canvas: &canvas) }
            updateCurrentCanvas(canvas)
        case .rectangle:
            guard let start = shapeStartPoint, var canvas = preShapeCanvas else { return }
            drawRectangle(canvas: &canvas, x0: start.x, y0: start.y, x1: x, y1: y, color: currentColor)
            if wrapPaintingEnabled { applyEdgeWrapping(canvas: &canvas) }
            updateCurrentCanvas(canvas)
        default:
            break
        }
        shapeStartPoint = nil
        preShapeCanvas = nil

        applyCurrentTemplate()
    }

    private func applyTool(at x: Int, y: Int) {
        var canvas = currentCanvas

        switch currentTool {
        case .pen:
            canvas.setPixel(at: x, y: y, color: currentColor)
            if wrapPaintingEnabled {
                applyWrappedPixels(canvas: &canvas, x: x, y: y, color: currentColor)
            }
        case .eraser:
            canvas.setPixel(at: x, y: y, color: nil)
            if wrapPaintingEnabled {
                applyWrappedPixels(canvas: &canvas, x: x, y: y, color: nil)
            }
        case .fill:
            floodFill(canvas: &canvas, x: x, y: y, newColor: currentColor, wrap: wrapPaintingEnabled)
            if wrapPaintingEnabled { applyEdgeWrapping(canvas: &canvas) }
        case .eyedropper:
            if let color = canvas.pixel(at: x, y: y) {
                currentColor = color
                currentTool = .pen
            }
            return
        case .line, .rectangle:
            break
        }

        updateCurrentCanvas(canvas)
    }

    /// Spiegelt Pixel auf die gegenüberliegende Kante (für nahtlose Texturen, einzelner Pixel)
    private func applyWrappedPixels(canvas: inout PixelCanvas, x: Int, y: Int, color: Color?) {
        let w = canvas.width, h = canvas.height
        // Wenn am linken/rechten Rand: auch auf der anderen Seite zeichnen
        if x == 0 { canvas.setPixel(at: w - 1, y: y, color: color) }
        if x == w - 1 { canvas.setPixel(at: 0, y: y, color: color) }
        // Wenn am oberen/unteren Rand: auch auf der anderen Seite zeichnen
        if y == 0 { canvas.setPixel(at: x, y: h - 1, color: color) }
        if y == h - 1 { canvas.setPixel(at: x, y: 0, color: color) }
        // Ecken
        if x == 0 && y == 0 { canvas.setPixel(at: w - 1, y: h - 1, color: color) }
        if x == 0 && y == h - 1 { canvas.setPixel(at: w - 1, y: 0, color: color) }
        if x == w - 1 && y == 0 { canvas.setPixel(at: 0, y: h - 1, color: color) }
        if x == w - 1 && y == h - 1 { canvas.setPixel(at: 0, y: 0, color: color) }
    }

    /// Spiegelt alle Rand-Pixel auf die gegenüberliegende Kante (für Linie/Rechteck/Fill)
    private func applyEdgeWrapping(canvas: inout PixelCanvas) {
        let w = canvas.width, h = canvas.height
        // Links ↔ Rechts
        for y in 0..<h {
            let leftColor = canvas.pixel(at: 0, y: y)
            let rightColor = canvas.pixel(at: w - 1, y: y)
            if leftColor != nil { canvas.setPixel(at: w - 1, y: y, color: leftColor) }
            if rightColor != nil { canvas.setPixel(at: 0, y: y, color: rightColor) }
        }
        // Oben ↔ Unten
        for x in 0..<w {
            let topColor = canvas.pixel(at: x, y: 0)
            let bottomColor = canvas.pixel(at: x, y: h - 1)
            if topColor != nil { canvas.setPixel(at: x, y: h - 1, color: topColor) }
            if bottomColor != nil { canvas.setPixel(at: x, y: 0, color: bottomColor) }
        }
    }

    // MARK: - Flood Fill

    private func floodFill(canvas: inout PixelCanvas, x: Int, y: Int, newColor: Color, wrap: Bool = false) {
        let targetColor = canvas.pixel(at: x, y: y)
        if targetColor == newColor { return }

        var stack: [(Int, Int)] = [(x, y)]
        let w = canvas.width, h = canvas.height

        while let (cx, cy) = stack.popLast() {
            guard canvas.isValid(x: cx, y: cy) else {
                // Wrap-Modus: Koordinaten auf gegenüberliegende Seite mappen
                if wrap {
                    let wx = ((cx % w) + w) % w
                    let wy = ((cy % h) + h) % h
                    guard canvas.pixel(at: wx, y: wy) == targetColor else { continue }
                    canvas.setPixel(at: wx, y: wy, color: newColor)
                    stack.append((wx + 1, wy))
                    stack.append((wx - 1, wy))
                    stack.append((wx, wy + 1))
                    stack.append((wx, wy - 1))
                }
                continue
            }
            guard canvas.pixel(at: cx, y: cy) == targetColor else { continue }
            canvas.setPixel(at: cx, y: cy, color: newColor)

            if wrap {
                // Im Wrap-Modus: Koordinaten wrappen statt Grenzen prüfen
                stack.append((cx + 1 < w ? cx + 1 : 0, cy))
                stack.append((cx - 1 >= 0 ? cx - 1 : w - 1, cy))
                stack.append((cx, cy + 1 < h ? cy + 1 : 0))
                stack.append((cx, cy - 1 >= 0 ? cy - 1 : h - 1))
            } else {
                stack.append((cx + 1, cy))
                stack.append((cx - 1, cy))
                stack.append((cx, cy + 1))
                stack.append((cx, cy - 1))
            }
        }
    }

    // MARK: - Line Tool (Bresenham)

    private func drawLine(canvas: inout PixelCanvas, x0: Int, y0: Int, x1: Int, y1: Int, color: Color) {
        var x = x0
        var y = y0
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx + dy

        while true {
            canvas.setPixel(at: x, y: y, color: color)
            if x == x1 && y == y1 { break }
            let e2 = 2 * err
            if e2 >= dy {
                err += dy
                x += sx
            }
            if e2 <= dx {
                err += dx
                y += sy
            }
        }
    }

    // MARK: - Rectangle Tool

    private func drawRectangle(canvas: inout PixelCanvas, x0: Int, y0: Int, x1: Int, y1: Int, color: Color) {
        let minX = min(x0, x1)
        let maxX = max(x0, x1)
        let minY = min(y0, y1)
        let maxY = max(y0, y1)

        for x in minX...maxX {
            canvas.setPixel(at: x, y: minY, color: color)
            canvas.setPixel(at: x, y: maxY, color: color)
        }
        for y in minY...maxY {
            canvas.setPixel(at: minX, y: y, color: color)
            canvas.setPixel(at: maxX, y: y, color: color)
        }
    }

    // MARK: - Zoom

    func zoomIn() {
        zoomScale = min(zoomScale + 0.5, maxZoom)
    }

    func zoomOut() {
        zoomScale = max(zoomScale - 0.5, minZoom)
    }

    func resetZoom() {
        zoomScale = 1.0
    }

    // MARK: - Undo / Redo

    private func saveUndoState() {
        let current = currentCanvas
        undoStack.append(current)

        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }

        redoStack.removeAll()
        updateUndoRedoState()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(currentCanvas)
        updateCurrentCanvas(previous)
        updateUndoRedoState()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentCanvas)
        updateCurrentCanvas(next)
        updateUndoRedoState()
    }

    private func updateUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    func resetUndoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoRedoState()
    }

    // MARK: - Canvas leeren

    func clearCanvas() {
        saveUndoState()
        var canvas = currentCanvas
        canvas.clear()
        updateCurrentCanvas(canvas)
    }

    // MARK: - Canvas-Transformationen

    func mirrorHorizontal() {
        saveUndoState()
        let mirrored = currentCanvas.mirroredHorizontal()
        updateCurrentCanvas(mirrored)
        applyCurrentTemplate()
    }

    func mirrorVertical() {
        saveUndoState()
        let mirrored = currentCanvas.mirroredVertical()
        updateCurrentCanvas(mirrored)
        applyCurrentTemplate()
    }

    func rotateCW() {
        saveUndoState()
        let canvas = currentCanvas
        // Nur rotieren wenn Canvas quadratisch ist (sonst passen Dimensionen nicht)
        guard canvas.width == canvas.height else { return }
        let rotated = canvas.rotatedCW()
        updateCurrentCanvas(rotated)
        applyCurrentTemplate()
    }

    // MARK: - PNG Import

    /// Importiert ein CGImage in das aktuelle Canvas.
    /// Skaliert auf die aktuelle Canvas-Größe.
    func importImage(_ cgImage: CGImage) {
        let canvas = currentCanvas
        guard let imported = PixelCanvas.fromCGImage(
            cgImage,
            targetWidth: canvas.width,
            targetHeight: canvas.height
        ) else { return }

        saveUndoState()
        updateCurrentCanvas(imported)
        applyCurrentTemplate()
    }

    // MARK: - Tile-Seamless Check

    func runTileCheck() {
        tileCheckResult = currentCanvas.checkTileSeamless(tolerant: tileCheckTolerant)
    }

    func clearTileCheck() {
        tileCheckResult = nil
    }

    // MARK: - Palette Reduce

    func reduceToPalette(_ palette: [Color], dithering: Bool = false) {
        saveUndoState()
        let reduced = currentCanvas.reducedToPalette(palette, dithering: dithering)
        updateCurrentCanvas(reduced)
        applyCurrentTemplate()
    }
}
