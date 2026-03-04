//
//  PaintingViewModel.swift
//  VoxelSprite
//
//  Verwaltet das Painting-Projekt.
//  Zuständig für: Canvas-Zugriff, Größenänderung, Export-Vorbereitung.
//

import SwiftUI
import Combine

class PaintingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var project: PaintingProject

    // MARK: - Init

    init() {
        self.project = PaintingProject()
    }

    // MARK: - Canvas-Zugriff (für CanvasViewModel-Kompatibilität)

    var activeCanvas: PixelCanvas {
        project.canvas
    }

    func updateActiveCanvas(_ canvas: PixelCanvas) {
        project.canvas = canvas
    }

    // MARK: - Größe ändern

    func resize(to size: PaintingSize) {
        project.resize(to: size)
    }

    // MARK: - Projekt-Operationen

    func newProject(size: PaintingSize = .s2x2) {
        project = PaintingProject(size: size)
    }

    // MARK: - Template-Stubs (für CanvasViewModel-Kompatibilität)

    func applyTemplate() {
        // Paintings haben keine Templates
    }

    func scheduleStrokeAutosave() {
        // TODO: Autosave für Paintings
    }
}
