//
//  CanvasViewModel.swift
//  PlanktonSpriteApp
//
//  Created by Andreas Pelczer on 27.02.26.
//


import SwiftUI
import Combine

/// Steuert alles rund ums Zeichnen auf dem Canvas.
/// Die View bindet sich an die @Published Properties,
/// das ViewModel ruft Operationen auf dem Model auf.
class CanvasViewModel: ObservableObject {

    // MARK: - Werkzeuge

    /// Verfügbare Zeichenwerkzeuge
    enum Tool: String, CaseIterable {
        case pen = "Stift"
        case eraser = "Radierer"
        case fill = "Füllen"
        case line = "Linie"
        case rectangle = "Rechteck"

        /// SF Symbol Name für die Toolbar-Icons
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
    
    /// Aktuell gewähltes Werkzeug
    @Published var currentTool: Tool = .pen
    
    /// Aktuell gewählte Zeichenfarbe
    @Published var currentColor: Color = .cyan
    
    /// Rasterlinien anzeigen ja/nein
    @Published var showGrid: Bool = true
    
    /// Undo-Stack: speichert vorherige Canvas-Zustände
    @Published private(set) var canUndo: Bool = false
    
    /// Redo-Stack: speichert rückgängig gemachte Zustände
    @Published private(set) var canRedo: Bool = false

    // MARK: - Onion Skin

    /// Onion Skin aktiviert
    @Published var onionSkinEnabled: Bool = false

    /// Vorheriges Frame anzeigen
    @Published var onionSkinPrevious: Bool = true

    /// Nächstes Frame anzeigen
    @Published var onionSkinNext: Bool = false

    /// Transparenz des Onion Skin Overlays (0.0–1.0)
    @Published var onionSkinOpacity: Double = 0.3

    // MARK: - Zoom

    /// Aktueller Zoom-Level (1.0 = 100%)
    @Published var zoomScale: CGFloat = 1.0

    /// Minimaler Zoom
    let minZoom: CGFloat = 0.5

    /// Maximaler Zoom
    let maxZoom: CGFloat = 4.0

    // MARK: - Line/Shape Tool State

    /// Startpunkt für Linien/Rechteck-Tool
    @Published var shapeStartPoint: (x: Int, y: Int)?

    /// Canvas-Zustand vor Shape-Preview (für Live-Vorschau)
    private var preShapeCanvas: PixelCanvas?

    // MARK: - Undo/Redo Stacks

    /// Vorherige Zustände – max 50 in Free
    private var undoStack: [PixelCanvas] = []

    /// Rückgängig gemachte Zustände
    private var redoStack: [PixelCanvas] = []

    /// Maximale Anzahl gespeicherter Undo-Schritte
    var maxUndoSteps = 50
    
    // MARK: - Referenz zum Projekt
    
    /// Das FrameViewModel besitzt das Projekt.
    /// Wir bekommen eine Referenz, um den aktiven Frame zu bearbeiten.
    private weak var frameViewModel: FrameViewModel?
    
    // MARK: - Init
    
    init() {}
    
    /// Verbindet dieses ViewModel mit dem FrameViewModel.
    /// Wird einmal beim App-Start aufgerufen.
    func connect(to frameViewModel: FrameViewModel) {
        self.frameViewModel = frameViewModel
    }
    
    // MARK: - Aktuelles Canvas
    
    /// Holt das Canvas des aktuell aktiven Frames.
    /// Convenience-Zugriff, damit wir nicht jedes Mal
    /// durch frameViewModel navigieren müssen.
    var currentCanvas: PixelCanvas {
        frameViewModel?.activeCanvas ?? PixelCanvas()
    }
    
    // MARK: - Zeichenoperationen
    
    /// Wird aufgerufen wenn der Finger/Stift das Canvas BERÜHRT.
    /// Speichert den Zustand für Undo, dann malt den ersten Pixel.
    func beginStroke(at x: Int, y: Int) {
        saveUndoState()

        switch currentTool {
        case .line, .rectangle:
            shapeStartPoint = (x, y)
            preShapeCanvas = frameViewModel?.activeCanvas
        default:
            applyTool(at: x, y: y)
        }
    }

    /// Wird aufgerufen wenn der Finger/Stift sich BEWEGT.
    /// Malt weitere Pixel ohne neuen Undo-Zustand.
    func continueStroke(at x: Int, y: Int) {
        switch currentTool {
        case .line:
            guard let start = shapeStartPoint, var canvas = preShapeCanvas else { return }
            drawLine(canvas: &canvas, x0: start.x, y0: start.y, x1: x, y1: y, color: currentColor)
            frameViewModel?.updateActiveCanvas(canvas)
        case .rectangle:
            guard let start = shapeStartPoint, var canvas = preShapeCanvas else { return }
            drawRectangle(canvas: &canvas, x0: start.x, y0: start.y, x1: x, y1: y, color: currentColor)
            frameViewModel?.updateActiveCanvas(canvas)
        default:
            applyTool(at: x, y: y)
        }
    }

    /// Wird aufgerufen wenn der Finger/Stift losgelassen wird.
    /// Finalisiert Linien/Rechteck-Operationen.
    func endStroke(at x: Int, y: Int) {
        switch currentTool {
        case .line:
            guard let start = shapeStartPoint, var canvas = preShapeCanvas else { return }
            drawLine(canvas: &canvas, x0: start.x, y0: start.y, x1: x, y1: y, color: currentColor)
            frameViewModel?.updateActiveCanvas(canvas)
        case .rectangle:
            guard let start = shapeStartPoint, var canvas = preShapeCanvas else { return }
            drawRectangle(canvas: &canvas, x0: start.x, y0: start.y, x1: x, y1: y, color: currentColor)
            frameViewModel?.updateActiveCanvas(canvas)
        default:
            break
        }
        shapeStartPoint = nil
        preShapeCanvas = nil
        // Debounced Autosave nach Zeichenende
        frameViewModel?.scheduleStrokeAutosave()
    }

    /// Wendet das aktuelle Werkzeug auf die Koordinate an.
    private func applyTool(at x: Int, y: Int) {
        guard var canvas = frameViewModel?.activeCanvas else { return }

        switch currentTool {
        case .pen:
            canvas.setPixel(at: x, y: y, color: currentColor)
        case .eraser:
            canvas.setPixel(at: x, y: y, color: nil)
        case .fill:
            floodFill(canvas: &canvas, x: x, y: y, newColor: currentColor)
        case .line, .rectangle:
            break // handled in begin/continue/endStroke
        }

        frameViewModel?.updateActiveCanvas(canvas)
    }
    
    // MARK: - Flood Fill
    
    /// Füllt zusammenhängende Pixel gleicher Farbe.
    /// Klassischer Stack-basierter Algorithmus, keine Rekursion
    /// (Rekursion würde bei 32×32 = 1024 Pixeln den Stack sprengen können).
    private func floodFill(canvas: inout PixelCanvas, x: Int, y: Int, newColor: Color) {
        let targetColor = canvas.pixel(at: x, y: y)
        
        // Wenn Zielfarbe = neue Farbe → nichts zu tun
        if targetColor == newColor { return }
        
        // Stack statt Rekursion
        var stack: [(Int, Int)] = [(x, y)]
        
        while let (cx, cy) = stack.popLast() {
            // Grenzen prüfen
            guard canvas.isValid(x: cx, y: cy) else { continue }
            
            // Nur Pixel mit der Zielfarbe füllen
            guard canvas.pixel(at: cx, y: cy) == targetColor else { continue }
            
            // Pixel setzen
            canvas.setPixel(at: cx, y: cy, color: newColor)
            
            // Nachbarn auf den Stack
            stack.append((cx + 1, cy))
            stack.append((cx - 1, cy))
            stack.append((cx, cy + 1))
            stack.append((cx, cy - 1))
        }
    }
    
    // MARK: - Line Tool (Bresenham)

    /// Zeichnet eine Linie mit dem Bresenham-Algorithmus.
    /// Pixel-perfekt, keine Anti-Aliasing-Magie.
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

    /// Zeichnet ein Rechteck (nur Umriss) zwischen zwei Eckpunkten.
    private func drawRectangle(canvas: inout PixelCanvas, x0: Int, y0: Int, x1: Int, y1: Int, color: Color) {
        let minX = min(x0, x1)
        let maxX = max(x0, x1)
        let minY = min(y0, y1)
        let maxY = max(y0, y1)

        // Obere und untere Kante
        for x in minX...maxX {
            canvas.setPixel(at: x, y: minY, color: color)
            canvas.setPixel(at: x, y: maxY, color: color)
        }
        // Linke und rechte Kante
        for y in minY...maxY {
            canvas.setPixel(at: minX, y: y, color: color)
            canvas.setPixel(at: maxX, y: y, color: color)
        }
    }

    // MARK: - Zoom

    /// Zoom vergrößern
    func zoomIn() {
        zoomScale = min(zoomScale + 0.5, maxZoom)
    }

    /// Zoom verkleinern
    func zoomOut() {
        zoomScale = max(zoomScale - 0.5, minZoom)
    }

    /// Zoom zurücksetzen
    func resetZoom() {
        zoomScale = 1.0
    }

    // MARK: - Undo / Redo
    
    /// Speichert den aktuellen Canvas-Zustand auf den Undo-Stack.
    /// Wird VOR jeder Zeichenoperation aufgerufen.
    private func saveUndoState() {
        let current = currentCanvas
        undoStack.append(current)
        
        // Stack begrenzen
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
        
        // Redo-Stack leeren – nach einer neuen Aktion
        // gibt es keinen "Zukunftsstrang" mehr
        redoStack.removeAll()
        
        updateUndoRedoState()
    }
    
    /// Macht die letzte Aktion rückgängig
    func undo() {
        guard let previous = undoStack.popLast() else { return }
        
        // Aktuellen Zustand auf Redo-Stack schieben
        redoStack.append(currentCanvas)
        
        // Vorherigen Zustand wiederherstellen
        frameViewModel?.updateActiveCanvas(previous)
        
        updateUndoRedoState()
    }
    
    /// Stellt die letzte rückgängig gemachte Aktion wieder her
    func redo() {
        guard let next = redoStack.popLast() else { return }
        
        // Aktuellen Zustand auf Undo-Stack schieben
        undoStack.append(currentCanvas)
        
        // Nächsten Zustand wiederherstellen
        frameViewModel?.updateActiveCanvas(next)
        
        updateUndoRedoState()
    }
    
    /// Aktualisiert die Published Booleans für die UI
    private func updateUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    // MARK: - Undo/Redo zurücksetzen

    /// Löscht die Undo/Redo-Historie.
    /// Wird beim Laden/Neu-Erstellen eines Projekts aufgerufen.
    func resetUndoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoRedoState()
    }

    // MARK: - Canvas leeren
    
    /// Löscht alle Pixel des aktiven Frames
    func clearCanvas() {
        saveUndoState()
        var canvas = currentCanvas
        canvas.clear()
        frameViewModel?.updateActiveCanvas(canvas)
        frameViewModel?.autosave()
    }
}

