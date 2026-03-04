//
//  WorkspaceManager.swift
//  VoxelSprite
//
//  Zentrale Verwaltung für Workspace-Autosave und Save/Load.
//  Speichert den kompletten Zustand aller Editor-Modi als .voxelwork Datei.
//

import SwiftUI
import Combine

class WorkspaceManager: ObservableObject {

    // MARK: - Published State

    /// Pfad der aktuell geöffneten Workspace-Datei (nil = noch nicht gespeichert)
    @Published var currentFileURL: URL?

    // MARK: - Referenzen

    private weak var blockVM: BlockViewModel?
    private weak var skinVM: SkinViewModel?
    private weak var itemVM: ItemViewModel?
    private weak var paintingVM: PaintingViewModel?
    private weak var entityVM: EntityViewModel?
    private weak var armorVM: ArmorViewModel?
    private weak var recipeVM: RecipeViewModel?

    // MARK: - Timer

    private var autosaveTimer: Timer?
    private var strokeDebounceTimer: Timer?

    // MARK: - Autosave Verzeichnis

    static let autosaveDirectory: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("VoxelSprite/WorkspaceAutosave", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static var autosaveLatestURL: URL {
        autosaveDirectory.appendingPathComponent("workspace_latest.voxelwork")
    }
    static var autosavePreviousURL: URL {
        autosaveDirectory.appendingPathComponent("workspace_previous.voxelwork")
    }

    // MARK: - Init

    init() {}

    // MARK: - Connect

    func connect(
        blockVM: BlockViewModel,
        skinVM: SkinViewModel,
        itemVM: ItemViewModel,
        paintingVM: PaintingViewModel,
        entityVM: EntityViewModel,
        armorVM: ArmorViewModel,
        recipeVM: RecipeViewModel
    ) {
        self.blockVM = blockVM
        self.skinVM = skinVM
        self.itemVM = itemVM
        self.paintingVM = paintingVM
        self.entityVM = entityVM
        self.armorVM = armorVM
        self.recipeVM = recipeVM
    }

    // MARK: - Autosave

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

    /// Wird von ViewModels nach jedem Strich aufgerufen.
    /// Debounced: Speichert erst nach 1 Sekunde Inaktivität.
    func scheduleStrokeAutosave() {
        strokeDebounceTimer?.invalidate()
        strokeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.autosave()
        }
    }

    func autosave() {
        guard let data = encodeWorkspace() else { return }

        let fm = FileManager.default
        if fm.fileExists(atPath: Self.autosaveLatestURL.path) {
            try? fm.removeItem(at: Self.autosavePreviousURL)
            try? fm.moveItem(at: Self.autosaveLatestURL, to: Self.autosavePreviousURL)
        }
        try? data.write(to: Self.autosaveLatestURL, options: .atomic)
    }

    var hasAutosave: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: Self.autosaveLatestURL.path)
            || fm.fileExists(atPath: Self.autosavePreviousURL.path)
    }

    // MARK: - Save / Load

    func saveWorkspace(to url: URL) throws {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

        guard let data = encodeWorkspace() else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
        currentFileURL = url
    }

    func loadWorkspace(from url: URL) throws {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        try decodeWorkspace(from: data)
        currentFileURL = url
    }

    func loadAutosave() throws {
        let fm = FileManager.default
        let url: URL
        if fm.fileExists(atPath: Self.autosaveLatestURL.path) {
            url = Self.autosaveLatestURL
        } else if fm.fileExists(atPath: Self.autosavePreviousURL.path) {
            url = Self.autosavePreviousURL
        } else {
            return
        }

        let data = try Data(contentsOf: url)
        try decodeWorkspace(from: data)
        currentFileURL = nil
    }

    // MARK: - Encode / Decode

    private func encodeWorkspace() -> Data? {
        guard let blockVM = blockVM,
              let skinVM = skinVM,
              let itemVM = itemVM,
              let paintingVM = paintingVM,
              let entityVM = entityVM,
              let armorVM = armorVM,
              let recipeVM = recipeVM else { return nil }

        let workspace = VoxelWorkspaceFile(
            blockProject: blockVM.project,
            skinProject: skinVM.project,
            itemProject: itemVM.project,
            paintingProject: paintingVM.project,
            entityProject: entityVM.project,
            armorProject: armorVM.project,
            recipe: recipeVM.recipe
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(workspace)
    }

    private func decodeWorkspace(from data: Data) throws {
        let workspace = try JSONDecoder().decode(VoxelWorkspaceFile.self, from: data)

        if let blockData = workspace.block {
            blockVM?.project = blockData.toProject()
        }
        if let skinData = workspace.skin {
            skinVM?.project = skinData.toProject()
            skinVM?.refreshEditCanvas()
        }
        if let itemData = workspace.item {
            itemVM?.project = itemData.toProject()
        }
        if let paintingData = workspace.painting {
            paintingVM?.project = paintingData.toProject()
        }
        if let entityData = workspace.entity {
            entityVM?.project = entityData.toProject()
            entityVM?.refreshEditCanvas()
        }
        if let armorData = workspace.armor {
            armorVM?.project = armorData.toProject()
            armorVM?.refreshEditCanvas()
        }
        if let recipeData = workspace.recipe {
            recipeVM?.recipe = recipeData.toRecipe()
        }
    }
}
