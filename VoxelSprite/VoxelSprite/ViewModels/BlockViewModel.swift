//
//  BlockViewModel.swift
//  VoxelSprite
//
//  Verwaltet das Block-Projekt mit seinen 6 Faces.
//  Ersetzt den FrameViewModel aus PlanktonSprite.
//  Zuständig für: aktives Face, Projekt-Operationen, Autosave.
//

import SwiftUI
import Combine

class BlockViewModel: ObservableObject {

    // MARK: - Published State

    /// Das komplette Block-Projekt
    @Published var project: BlockProject

    /// Das aktuell bearbeitete Face
    @Published var activeFaceType: FaceType = .north

    /// Pfad der aktuell geöffneten Datei (nil = noch nicht gespeichert)
    @Published var currentFileURL: URL?

    // MARK: - Init

    init() {
        self.project = BlockProject()
    }

    // MARK: - Computed Properties

    /// Das Canvas des aktiven Faces
    var activeCanvas: PixelCanvas {
        project.canvas(for: activeFaceType)
    }

    /// Das aktive Face
    var activeFace: BlockFace {
        project.face(for: activeFaceType)
    }

    /// Alle Faces als sortiertes Array
    var orderedFaces: [BlockFace] {
        project.orderedFaces
    }

    // MARK: - Canvas aktualisieren

    /// Schreibt ein verändertes Canvas zurück in das aktive Face
    func updateActiveCanvas(_ canvas: PixelCanvas) {
        project.updateCanvas(for: activeFaceType, canvas: canvas)
    }

    // MARK: - Face-Navigation

    /// Wechselt zum angegebenen Face
    func selectFace(_ type: FaceType) {
        activeFaceType = type
    }

    /// Wechselt zum nächsten Face
    func nextFace() {
        let allFaces = FaceType.allCases
        guard let currentIndex = allFaces.firstIndex(of: activeFaceType) else { return }
        let nextIndex = (currentIndex + 1) % allFaces.count
        activeFaceType = allFaces[nextIndex]
    }

    /// Wechselt zum vorherigen Face
    func previousFace() {
        let allFaces = FaceType.allCases
        guard let currentIndex = allFaces.firstIndex(of: activeFaceType) else { return }
        let prevIndex = (currentIndex - 1 + allFaces.count) % allFaces.count
        activeFaceType = allFaces[prevIndex]
    }

    // MARK: - Template-Operationen

    /// Wendet das aktuelle Template an:
    /// Kopiert das aktive Face auf alle verknüpften Faces
    func applyTemplate() {
        project.applyTemplate(from: activeFaceType)
    }

    // MARK: - Projekt: Neu / Speichern / Laden

    /// Erstellt ein neues leeres Projekt
    func newProject(gridSize: Int = 16, template: BlockTemplate = .custom) {
        project = BlockProject(gridSize: gridSize, template: template)
        activeFaceType = .north
        currentFileURL = nil
    }

    /// Speichert das Projekt als .voxel JSON-Datei
    func saveProject(to url: URL) throws {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

        let file = VoxelProjectFile(from: project)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(file)
        try data.write(to: url, options: .atomic)
        currentFileURL = url
        project.name = url.deletingPathExtension().lastPathComponent
    }

    /// Lädt ein Projekt aus einer .voxel Datei
    func loadProject(from url: URL) throws {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(VoxelProjectFile.self, from: data)
        project = file.toProject()
        activeFaceType = .north
        currentFileURL = url
    }

    // MARK: - Autosave

    private var autosaveTimer: Timer?
    private var strokeDebounceTimer: Timer?

    static let autosaveDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("VoxelSprite/Autosave", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static var autosaveLatestURL: URL {
        autosaveDirectory.appendingPathComponent("autosave_latest.voxel")
    }
    static var autosavePreviousURL: URL {
        autosaveDirectory.appendingPathComponent("autosave_previous.voxel")
    }

    func startAutosave() {
        autosaveTimer?.invalidate()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.autosave()
        }
    }

    func stopAutosave() {
        autosaveTimer?.invalidate()
        autosaveTimer = nil
        strokeDebounceTimer?.invalidate()
        strokeDebounceTimer = nil
    }

    func scheduleStrokeAutosave() {
        strokeDebounceTimer?.invalidate()
        strokeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.autosave()
        }
    }

    func autosave() {
        let savedURL = currentFileURL
        let file = VoxelProjectFile(from: project)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(file) else { return }

        let fm = FileManager.default
        if fm.fileExists(atPath: Self.autosaveLatestURL.path) {
            try? fm.removeItem(at: Self.autosavePreviousURL)
            try? fm.moveItem(at: Self.autosaveLatestURL, to: Self.autosavePreviousURL)
        }
        try? data.write(to: Self.autosaveLatestURL, options: .atomic)
        currentFileURL = savedURL
    }

    var hasAutosave: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: Self.autosaveLatestURL.path)
            || fm.fileExists(atPath: Self.autosavePreviousURL.path)
    }

    func loadAutosave() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: Self.autosaveLatestURL.path) {
            try loadProject(from: Self.autosaveLatestURL)
        } else if fm.fileExists(atPath: Self.autosavePreviousURL.path) {
            try loadProject(from: Self.autosavePreviousURL)
        }
        currentFileURL = nil
    }
}
