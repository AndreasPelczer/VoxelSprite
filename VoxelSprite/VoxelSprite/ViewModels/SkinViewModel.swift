//
//  SkinViewModel.swift
//  VoxelSprite
//
//  Verwaltet das Skin-Projekt (Andy/Alex).
//  Zuständig für: aktives Körperteil, Face, Layer,
//  Canvas-Extraktion und -Rückschreibung.
//

import SwiftUI
import Combine

class SkinViewModel: ObservableObject {

    // MARK: - Published State

    @Published var project: SkinProject

    /// Aktuell ausgewähltes Körperteil
    @Published var activeBodyPart: SkinBodyPart = .head

    /// Aktuell ausgewählte Seite des Körperteils
    @Published var activeFace: SkinFace = .front

    /// Aktueller Layer (Base / Overlay)
    @Published var activeLayer: SkinLayer = .base

    /// Das extrahierte Canvas für die aktuelle Auswahl
    @Published var editCanvas: PixelCanvas

    /// Referenz zum Workspace-Manager für Autosave
    weak var workspaceManager: WorkspaceManager?

    // MARK: - Init

    init() {
        let proj = SkinProject()
        self.project = proj
        self.editCanvas = proj.extractRegion(bodyPart: .head, face: .front, layer: .base)
    }

    // MARK: - Canvas-Zugriff (für CanvasViewModel-Kompatibilität)

    var activeCanvas: PixelCanvas {
        editCanvas
    }

    func updateActiveCanvas(_ canvas: PixelCanvas) {
        editCanvas = canvas
        project.writeRegion(bodyPart: activeBodyPart, face: activeFace, layer: activeLayer, canvas: canvas)
    }

    // MARK: - Navigation

    func selectBodyPart(_ part: SkinBodyPart) {
        flushCurrentEdit()
        activeBodyPart = part
        refreshEditCanvas()
    }

    func selectFace(_ face: SkinFace) {
        flushCurrentEdit()
        activeFace = face
        refreshEditCanvas()
    }

    func selectLayer(_ layer: SkinLayer) {
        flushCurrentEdit()
        activeLayer = layer
        refreshEditCanvas()
    }

    // MARK: - Internes

    private func flushCurrentEdit() {
        project.writeRegion(bodyPart: activeBodyPart, face: activeFace, layer: activeLayer, canvas: editCanvas)
    }

    func refreshEditCanvas() {
        editCanvas = project.extractRegion(bodyPart: activeBodyPart, face: activeFace, layer: activeLayer)
    }

    // MARK: - Projekt-Operationen

    func newProject() {
        project = SkinProject()
        activeBodyPart = .head
        activeFace = .front
        activeLayer = .base
        refreshEditCanvas()
    }

    // MARK: - Template-Stubs (für CanvasViewModel-Kompatibilität)

    func applyTemplate() {
        // Skins haben keine Templates
    }

    func scheduleStrokeAutosave() {
        workspaceManager?.scheduleStrokeAutosave()
    }

    // MARK: - Overlay Canvas (zeigt den anderen Layer)

    func overlayCanvas() -> PixelCanvas? {
        let otherLayer: SkinLayer = activeLayer == .base ? .overlay : .base
        return project.extractRegion(bodyPart: activeBodyPart, face: activeFace, layer: otherLayer)
    }
}
