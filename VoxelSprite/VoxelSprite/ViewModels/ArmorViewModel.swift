//
//  ArmorViewModel.swift
//  VoxelSprite
//
//  Verwaltet das Rüstungs-Textur-Projekt (Armor).
//  Zuständig für: aktives Rüstungsteil, Face, Layer,
//  Canvas-Extraktion und -Rückschreibung.
//

import SwiftUI
import Combine

class ArmorViewModel: ObservableObject {

    // MARK: - Published State

    @Published var project: ArmorProject

    /// Aktuell ausgewähltes Rüstungsteil
    @Published var activePiece: ArmorPiece = .helmet

    /// Aktuell ausgewählte Seite
    @Published var activeFace: SkinFace = .front

    /// Das extrahierte Canvas für die aktuelle Auswahl
    @Published var editCanvas: PixelCanvas

    // MARK: - Init

    init() {
        let proj = ArmorProject()
        self.project = proj
        self.editCanvas = proj.extractRegion(piece: .helmet, face: .front)
    }

    // MARK: - Aktueller Layer (abgeleitet vom aktiven Piece)

    var activeLayer: ArmorLayer {
        activePiece.armorLayer
    }

    // MARK: - Canvas-Zugriff (für CanvasViewModel-Kompatibilität)

    var activeCanvas: PixelCanvas {
        editCanvas
    }

    func updateActiveCanvas(_ canvas: PixelCanvas) {
        editCanvas = canvas
        project.writeRegion(piece: activePiece, face: activeFace, canvas: canvas)
    }

    // MARK: - Navigation

    func selectPiece(_ piece: ArmorPiece) {
        flushCurrentEdit()
        activePiece = piece
        refreshEditCanvas()
    }

    func selectFace(_ face: SkinFace) {
        flushCurrentEdit()
        activeFace = face
        refreshEditCanvas()
    }

    // MARK: - Internes

    private func flushCurrentEdit() {
        project.writeRegion(piece: activePiece, face: activeFace, canvas: editCanvas)
    }

    func refreshEditCanvas() {
        editCanvas = project.extractRegion(piece: activePiece, face: activeFace)
    }

    // MARK: - Projekt-Operationen

    func newProject(material: ArmorMaterial = .iron) {
        project = ArmorProject(material: material)
        activePiece = .helmet
        activeFace = .front
        refreshEditCanvas()
    }

    // MARK: - Overlay Canvas (zeigt den anderen Layer)

    func overlayCanvas() -> PixelCanvas? {
        // Kein sinnvolles Overlay für Rüstungen
        nil
    }

    // MARK: - Template-Stubs (für CanvasViewModel-Kompatibilität)

    func applyTemplate() {
        // Rüstungen haben keine Templates
    }

    func scheduleStrokeAutosave() {
        // TODO: Autosave für Armor
    }
}
