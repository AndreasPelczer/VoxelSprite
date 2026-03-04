//
//  BlockViewModel.swift
//  VoxelSprite
//
//  Verwaltet das Block-Projekt mit seinen 6 Faces.
//  Zuständig für: aktives Face, Frame-Navigation, Projekt-Operationen, Autosave.
//

import SwiftUI
import Combine

class BlockViewModel: ObservableObject {

    // MARK: - Published State

    /// Das komplette Block-Projekt
    @Published var project: BlockProject

    /// Das aktuell bearbeitete Face
    @Published var activeFaceType: FaceType = .north

    /// Der aktive Frame-Index (für Animation/CTM)
    @Published var activeFrameIndex: Int = 0

    /// Pfad der aktuell geöffneten Datei (nil = noch nicht gespeichert)
    @Published var currentFileURL: URL?

    /// Referenz zum Workspace-Manager für Autosave
    weak var workspaceManager: WorkspaceManager?

    // MARK: - Init

    init() {
        self.project = BlockProject()
    }

    // MARK: - Computed Properties

    /// Das Canvas des aktiven Faces im aktiven Frame
    var activeCanvas: PixelCanvas {
        let face = project.face(for: activeFaceType)
        let idx = min(activeFrameIndex, face.frames.count - 1)
        return idx >= 0 ? face.frames[idx] : PixelCanvas(gridSize: project.gridSize)
    }

    /// Das aktive Face
    var activeFace: BlockFace {
        project.face(for: activeFaceType)
    }

    /// Alle Faces als sortiertes Array
    var orderedFaces: [BlockFace] {
        project.orderedFaces
    }

    /// Anzahl Frames des aktiven Faces
    var activeFrameCount: Int {
        activeFace.frameCount
    }

    // MARK: - Canvas aktualisieren

    /// Schreibt ein verändertes Canvas zurück in den aktiven Frame
    func updateActiveCanvas(_ canvas: PixelCanvas) {
        let count = project.faces[activeFaceType]?.frames.count ?? 0
        let idx = min(activeFrameIndex, count - 1)
        guard idx >= 0 else { return }
        project.faces[activeFaceType]?.frames[idx] = canvas
    }

    // MARK: - Face-Navigation

    /// Wechselt zum angegebenen Face
    func selectFace(_ type: FaceType) {
        activeFaceType = type
        activeFrameIndex = 0
    }

    /// Wechselt zum nächsten Face
    func nextFace() {
        let allFaces = FaceType.allCases
        guard let currentIndex = allFaces.firstIndex(of: activeFaceType) else { return }
        let nextIndex = (currentIndex + 1) % allFaces.count
        activeFaceType = allFaces[nextIndex]
        activeFrameIndex = 0
    }

    /// Wechselt zum vorherigen Face
    func previousFace() {
        let allFaces = FaceType.allCases
        guard let currentIndex = allFaces.firstIndex(of: activeFaceType) else { return }
        let prevIndex = (currentIndex - 1 + allFaces.count) % allFaces.count
        activeFaceType = allFaces[prevIndex]
        activeFrameIndex = 0
    }

    // MARK: - Frame-Management

    /// Wechselt zum angegebenen Frame
    func selectFrame(_ index: Int) {
        let count = project.faces[activeFaceType]?.frames.count ?? 1
        activeFrameIndex = max(0, min(index, count - 1))
    }

    /// Fügt einen neuen leeren Frame hinzu
    func addFrame() {
        let gridSize = project.gridSize
        project.faces[activeFaceType]?.frames.append(PixelCanvas(gridSize: gridSize))
        activeFrameIndex = (project.faces[activeFaceType]?.frames.count ?? 1) - 1
    }

    /// Dupliziert den aktuellen Frame
    func duplicateFrame() {
        guard let face = project.faces[activeFaceType],
              activeFrameIndex < face.frames.count else { return }
        let copy = face.frames[activeFrameIndex]
        project.faces[activeFaceType]?.frames.insert(copy, at: activeFrameIndex + 1)
        activeFrameIndex += 1
    }

    /// Löscht den aktuellen Frame (mindestens 1 Frame muss bleiben)
    func deleteFrame() {
        guard let face = project.faces[activeFaceType],
              face.frames.count > 1,
              activeFrameIndex < face.frames.count else { return }
        project.faces[activeFaceType]?.frames.remove(at: activeFrameIndex)
        if activeFrameIndex >= (project.faces[activeFaceType]?.frames.count ?? 1) {
            activeFrameIndex = max(0, (project.faces[activeFaceType]?.frames.count ?? 1) - 1)
        }
    }

    /// Verschiebt einen Frame nach links
    func moveFrameLeft() {
        guard activeFrameIndex > 0 else { return }
        project.faces[activeFaceType]?.frames.swapAt(activeFrameIndex, activeFrameIndex - 1)
        activeFrameIndex -= 1
    }

    /// Verschiebt einen Frame nach rechts
    func moveFrameRight() {
        guard let face = project.faces[activeFaceType],
              activeFrameIndex < face.frames.count - 1 else { return }
        project.faces[activeFaceType]?.frames.swapAt(activeFrameIndex, activeFrameIndex + 1)
        activeFrameIndex += 1
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
        activeFrameIndex = 0
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
        activeFrameIndex = 0
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
            self?.workspaceManager?.scheduleStrokeAutosave()
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
