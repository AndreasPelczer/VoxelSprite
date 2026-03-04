//
//  EntityViewModel.swift
//  VoxelSprite
//
//  Verwaltet das Entity-Textur-Projekt (Mobs).
//  Zuständig für: Entity-Typ, aktives Körperteil, Face,
//  Canvas-Extraktion und -Rückschreibung.
//

import SwiftUI
import Combine

class EntityViewModel: ObservableObject {

    // MARK: - Published State

    @Published var project: EntityProject

    /// Aktuell ausgewählter Körperteil-Index
    @Published var activePartIndex: Int = 0

    /// Aktuell ausgewählte Seite des Körperteils
    @Published var activeFace: SkinFace = .front

    /// Das extrahierte Canvas für die aktuelle Auswahl
    @Published var editCanvas: PixelCanvas

    // MARK: - Init

    init() {
        let proj = EntityProject()
        self.project = proj
        let part = proj.entityType.bodyParts[0]
        self.editCanvas = proj.extractRegion(bodyPart: part, face: .front)
    }

    // MARK: - Aktueller Körperteil

    var activeBodyPart: EntityBodyPart {
        let parts = project.entityType.bodyParts
        guard activePartIndex >= 0, activePartIndex < parts.count else {
            return parts[0]
        }
        return parts[activePartIndex]
    }

    // MARK: - Canvas-Zugriff (für CanvasViewModel-Kompatibilität)

    var activeCanvas: PixelCanvas {
        editCanvas
    }

    func updateActiveCanvas(_ canvas: PixelCanvas) {
        editCanvas = canvas
        project.writeRegion(bodyPart: activeBodyPart, face: activeFace, canvas: canvas)
    }

    // MARK: - Navigation

    func selectPart(_ index: Int) {
        flushCurrentEdit()
        activePartIndex = index
        refreshEditCanvas()
    }

    func selectFace(_ face: SkinFace) {
        flushCurrentEdit()
        activeFace = face
        refreshEditCanvas()
    }

    func changeEntityType(_ type: EntityType) {
        flushCurrentEdit()
        project.changeType(to: type)
        activePartIndex = 0
        activeFace = .front
        refreshEditCanvas()
    }

    // MARK: - Internes

    private func flushCurrentEdit() {
        project.writeRegion(bodyPart: activeBodyPart, face: activeFace, canvas: editCanvas)
    }

    func refreshEditCanvas() {
        editCanvas = project.extractRegion(bodyPart: activeBodyPart, face: activeFace)
    }

    // MARK: - Projekt-Operationen

    func newProject(entityType: EntityType = .creeper) {
        project = EntityProject(entityType: entityType)
        activePartIndex = 0
        activeFace = .front
        refreshEditCanvas()
    }

    // MARK: - Template-Stubs (für CanvasViewModel-Kompatibilität)

    func applyTemplate() {
        // Entities haben keine Templates
    }

    func scheduleStrokeAutosave() {
        // TODO: Autosave für Entities
    }
}
