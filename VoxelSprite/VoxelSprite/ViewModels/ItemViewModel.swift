//
//  ItemViewModel.swift
//  VoxelSprite
//
//  Verwaltet das Item-Projekt.
//  Zuständig für: aktiver Layer, Layer-Navigation, Canvas-Zugriff.
//

import SwiftUI
import Combine

class ItemViewModel: ObservableObject {

    // MARK: - Published State

    /// Das Item-Projekt
    @Published var project: ItemProject

    /// Aktuell bearbeiteter Layer
    @Published var activeLayerIndex: Int = 0

    /// Referenz zum Workspace-Manager für Autosave
    weak var workspaceManager: WorkspaceManager?

    // MARK: - Init

    init() {
        self.project = ItemProject()
    }

    // MARK: - Canvas-Zugriff (für CanvasViewModel-Kompatibilität)

    /// Canvas des aktiven Layers
    var activeCanvas: PixelCanvas {
        let idx = min(activeLayerIndex, project.layers.count - 1)
        return idx >= 0 ? project.layers[idx] : PixelCanvas(gridSize: project.gridSize)
    }

    /// Schreibt ein verändertes Canvas zurück
    func updateActiveCanvas(_ canvas: PixelCanvas) {
        let idx = min(activeLayerIndex, project.layers.count - 1)
        guard idx >= 0 else { return }
        project.layers[idx] = canvas
    }

    // MARK: - Layer-Navigation

    /// Wechselt zum angegebenen Layer
    func selectLayer(_ index: Int) {
        activeLayerIndex = max(0, min(index, project.layers.count - 1))
    }

    /// Fügt einen neuen leeren Layer hinzu
    func addLayer() {
        project.layers.append(PixelCanvas(gridSize: project.gridSize))
        activeLayerIndex = project.layers.count - 1
    }

    /// Löscht den aktuellen Layer (mindestens 1 muss bleiben)
    func deleteLayer() {
        guard project.layers.count > 1,
              activeLayerIndex < project.layers.count else { return }
        project.layers.remove(at: activeLayerIndex)
        if activeLayerIndex >= project.layers.count {
            activeLayerIndex = project.layers.count - 1
        }
    }

    /// Verschiebt einen Layer nach unten (weiter hinten)
    func moveLayerDown() {
        guard activeLayerIndex > 0 else { return }
        project.layers.swapAt(activeLayerIndex, activeLayerIndex - 1)
        activeLayerIndex -= 1
    }

    /// Verschiebt einen Layer nach oben (weiter vorne)
    func moveLayerUp() {
        guard activeLayerIndex < project.layers.count - 1 else { return }
        project.layers.swapAt(activeLayerIndex, activeLayerIndex + 1)
        activeLayerIndex += 1
    }

    // MARK: - Projekt-Operationen

    /// Neues Item-Projekt
    func newProject(gridSize: Int = 16) {
        project = ItemProject(gridSize: gridSize)
        activeLayerIndex = 0
    }

    // MARK: - Overlay (zeigt andere Layer)

    /// Gibt ein Canvas mit allen anderen Layern als Overlay zurück
    func overlayCanvas() -> PixelCanvas? {
        guard project.layers.count > 1 else { return nil }

        var result = PixelCanvas(gridSize: project.gridSize)
        for (index, layer) in project.layers.enumerated() {
            if index == activeLayerIndex { continue }
            for y in 0..<project.gridSize {
                for x in 0..<project.gridSize {
                    if let color = layer.pixel(at: x, y: y) {
                        result.setPixel(at: x, y: y, color: color)
                    }
                }
            }
        }
        return result
    }

    // MARK: - Template-Stubs (für CanvasViewModel-Kompatibilität)

    func applyTemplate() {
        // Items haben keine Templates
    }

    func scheduleStrokeAutosave() {
        workspaceManager?.scheduleStrokeAutosave()
    }
}
