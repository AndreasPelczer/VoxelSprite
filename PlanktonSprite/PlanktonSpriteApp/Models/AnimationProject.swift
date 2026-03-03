//
//  AnimationProject.swift
//  PlanktonSpriteApp
//
//  Created by Andreas Pelczer on 27.02.26.
//


import SwiftUI

/// Das komplette Animationsprojekt.
/// Hält alle Frames und die globalen Einstellungen.
struct AnimationProject {

    // MARK: - Frames

    /// Alle Frames der Animation, in Reihenfolge.
    /// Mindestens ein Frame ist immer vorhanden.
    var frames: [SpriteFrame]

    // MARK: - Einstellungen

    /// Abspielgeschwindigkeit in Frames pro Sekunde.
    /// Bereich: 1–24, Standard: 6
    var fps: Int

    /// Name des Projekts – für Dateiexport und Anzeige
    var name: String

    /// Rastergröße des Projekts
    var gridSize: Int

    /// Loop-Modus: Animation wiederholen oder einmal abspielen
    var loopAnimation: Bool

    // MARK: - Init

    /// Erzeugt ein neues Projekt mit einem leeren Frame
    init(name: String = "Daumenkino", gridSize: Int = PixelCanvas.defaultGridSize) {
        self.name = name
        self.fps = 6
        self.gridSize = gridSize
        self.loopAnimation = true
        self.frames = [SpriteFrame(gridSize: gridSize)]
    }
    
    // MARK: - Frame-Zugriff
    
    /// Anzahl der Frames
    var frameCount: Int {
        frames.count
    }
    
    /// Sicherer Zugriff auf einen Frame per Index.
    /// Gibt nil zurück statt zu crashen.
    func frame(at index: Int) -> SpriteFrame? {
        guard isValidIndex(index) else { return nil }
        return frames[index]
    }
    
    // MARK: - Frame-Operationen
    
    /// Fügt einen leeren Frame NACH dem angegebenen Index ein.
    /// Gibt den Index des neuen Frames zurück.
    @discardableResult
    mutating func insertFrame(after index: Int) -> Int {
        let insertIndex = min(index + 1, frames.count)
        frames.insert(SpriteFrame(gridSize: gridSize), at: insertIndex)
        return insertIndex
    }
    
    /// Dupliziert den Frame am angegebenen Index.
    /// Die Kopie landet direkt dahinter.
    /// Gibt den Index der Kopie zurück, oder nil bei ungültigem Index.
    @discardableResult
    mutating func duplicateFrame(at index: Int) -> Int? {
        guard isValidIndex(index) else { return nil }
        let copy = SpriteFrame(canvas: frames[index].canvas, durationMs: frames[index].durationMs)
        let insertIndex = index + 1
        frames.insert(copy, at: insertIndex)
        return insertIndex
    }
    
    /// Löscht den Frame am Index.
    /// Verhindert das Löschen des letzten Frames – mindestens einer bleibt.
    /// Gibt true zurück wenn gelöscht wurde.
    @discardableResult
    mutating func deleteFrame(at index: Int) -> Bool {
        guard isValidIndex(index), frames.count > 1 else { return false }
        frames.remove(at: index)
        return true
    }
    
    /// Verschiebt einen Frame von einer Position zur anderen.
    /// Das ist die Logik hinter Drag & Drop.
    mutating func moveFrame(from source: Int, to destination: Int) {
        guard isValidIndex(source) else { return }
        let clampedDest = max(0, min(destination, frames.count - 1))
        let frame = frames.remove(at: source)
        frames.insert(frame, at: clampedDest)
    }
    
    // MARK: - Validierung
    
    func isValidIndex(_ index: Int) -> Bool {
        index >= 0 && index < frames.count
    }
}