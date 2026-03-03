//
//  CanvasViewModel.swift
//  VoxelSprite
//
//  Steuert alles rund ums Zeichnen auf dem Canvas.
//  Adaptiert von PlanktonSprite: Onion Skin → Face Overlay.
//

import SwiftUI
import Combine

class CanvasViewModel: ObservableObject {

    // MARK: - Werkzeuge

    enum Tool: String, CaseIterable {
        case pen       = "Stift"
        case eraser    = "Radierer"
        case fill      = "Füllen"
        case line      = "Linie"
        case rectangle = "Rechteck"

        var iconName: String {
            switch self {
            case .pen:       return "pencil"
            case .eraser:    return "eraser"
            case .fill:      return "drop.fill"
            case .line:      return "line.diagonal"
            case .rectangle: return "rectangle"
            }
        }
    }

    // MARK: - Published State

    @Published var currentTool: Tool = .pen
    @Published var currentColor: Color = .cyan
    @Published var showGrid: Bool = true
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    // MARK: - Face Overlay (ersetzt Onion Skin)

    /// Face Overlay: andere Faces halbtransparent einblenden
    @Published var faceOverlayEnabled: Bool = false

    /// Welches Face als Overlay anzeigen (nil = automatisch das gegenüberliegende)
    @Published var overlayFaceType: FaceType?

    /// Transparenz des Face Overlays
    @Published var faceOverlayOpacity: Double = 0.3

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

    // MARK: - Referenz zum Projekt

    private weak var blockViewModel: BlockViewModel?

    // MARK: - Init

    init() {}

    func connect(to blockViewModel: BlockViewModel) {
        self.blockViewModel = blockViewModel
    }

    // MARK: - Aktuelles Canvas

    var currentCanvas: PixelCanvas {
        blockViewModel?.activeCanvas ?? PixelCanvas(gridSize: 16)
    }

    // MARK: - Face Overlay Helpers

    /// Das gegenüberliegende Face für automatisches Overlay
    var oppositeFaceType: FaceType? {
        guard let blockVM = blockViewModel else { return nil }
        switch blockVM.activeFaceType {
        case .top:    return .bottom
        case .bottom: return .top
        case .north:  return .south
        case .south:  return .north
        case .east:   return .west
        case .west:   return .east
        }
    }

    /// Canvas des Overlay-Faces
    var overlayCanvas: PixelCanvas? {
        guard faceOverlayEnabled, let blockVM = blockViewModel else { return nil }
        let faceType = overlayFaceType ?? oppositeFaceType ?? .north
        return blockVM.project.canvas(for: faceType)
    }

    // MARK: - Zeichenoperationen

    func beginStroke(at x: Int, y: Int) {
        saveUndoState()

        switch currentTool {
        case .line, .rectangle:
            shapeStartPoint = (x, y)
            preShapeCanvas = blockViewModel?.activeCanvas
        default:
            applyTool(at: x, y: y)
        }
    }

    func continueStroke(at x: Int, y: Int) {
        switch currentTool {
        case .line:
            guard let start = shapeStartPoint, var canvas = preShapeCanvas else { return }
            drawLine(canvas: &canvas, x0: start.x, y0: start.y, x1: x, y1: y, color: currentColor)
            blockViewModel?.updateActiveCanvas(canvas)
        case .rectangle:
            guard let start = shapeStartPoint, var canvas = preShapeCanvas else { return }
            drawRectangle(canvas: &canvas, x0: start.x, y0: start.y, x1: x, y1: y, color: currentColor)
            blockViewModel?.updateActiveCanvas(canvas)
        default:
            applyTool(at: x, y: y)
        }
    }

    func endStroke(at x: Int, y: Int) {
        switch currentTool {
        case .line:
            guard let start = shapeStartPoint, var canvas = preShapeCanvas else { return }
            drawLine(canvas: &canvas, x0: start.x, y0: start.y, x1: x, y1: y, color: currentColor)
            blockViewModel?.updateActiveCanvas(canvas)
        case .rectangle:
            guard let start = shapeStartPoint, var canvas = preShapeCanvas else { return }
            drawRectangle(canvas: &canvas, x0: start.x, y0: start.y, x1: x, y1: y, color: currentColor)
            blockViewModel?.updateActiveCanvas(canvas)
        default:
            break
        }
        shapeStartPoint = nil
        preShapeCanvas = nil

        // Template anwenden nach dem Zeichnen
        blockViewModel?.applyTemplate()
        blockViewModel?.scheduleStrokeAutosave()
    }

    private func applyTool(at x: Int, y: Int) {
        guard var canvas = blockViewModel?.activeCanvas else { return }

        switch currentTool {
        case .pen:
            canvas.setPixel(at: x, y: y, color: currentColor)
        case .eraser:
            canvas.setPixel(at: x, y: y, color: nil)
        case .fill:
            floodFill(canvas: &canvas, x: x, y: y, newColor: currentColor)
        case .line, .rectangle:
            break
        }

        blockViewModel?.updateActiveCanvas(canvas)
    }

    // MARK: - Flood Fill

    private func floodFill(canvas: inout PixelCanvas, x: Int, y: Int, newColor: Color) {
        let targetColor = canvas.pixel(at: x, y: y)
        if targetColor == newColor { return }

        var stack: [(Int, Int)] = [(x, y)]

        while let (cx, cy) = stack.popLast() {
            guard canvas.isValid(x: cx, y: cy) else { continue }
            guard canvas.pixel(at: cx, y: cy) == targetColor else { continue }
            canvas.setPixel(at: cx, y: cy, color: newColor)
            stack.append((cx + 1, cy))
            stack.append((cx - 1, cy))
            stack.append((cx, cy + 1))
            stack.append((cx, cy - 1))
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
        blockViewModel?.updateActiveCanvas(previous)
        updateUndoRedoState()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentCanvas)
        blockViewModel?.updateActiveCanvas(next)
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
        blockViewModel?.updateActiveCanvas(canvas)
        blockViewModel?.autosave()
    }
}
