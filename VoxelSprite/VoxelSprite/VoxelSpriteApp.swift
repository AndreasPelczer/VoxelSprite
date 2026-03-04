//
//  VoxelSpriteApp.swift
//  VoxelSprite
//
//  Entry Point der App.
//  Hier werden alle ViewModels erzeugt und miteinander verbunden.
//  Enthält die macOS-Menüleiste (Datei/Bearbeiten/Block).
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct VoxelSpriteApp: App {

    // MARK: - ViewModels

    @StateObject private var blockVM = BlockViewModel()
    @StateObject private var canvasVM = CanvasViewModel()
    @StateObject private var exportVM = ExportViewModel()
    @StateObject private var itemVM = ItemViewModel()
    @StateObject private var paletteManager = PaletteManager()
    @StateObject private var skinVM = SkinViewModel()
    @StateObject private var paintingVM = PaintingViewModel()
    @StateObject private var recipeVM = RecipeViewModel()
    @StateObject private var resourcepackVM = ResourcepackViewModel()

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Datei-Dialog State

    @State private var showSaveDialog = false
    @State private var showOpenDialog = false
    @State private var documentToSave: VoxelDocument?

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(blockVM)
                .environmentObject(canvasVM)
                .environmentObject(exportVM)
                .environmentObject(itemVM)
                .environmentObject(paletteManager)
                .environmentObject(skinVM)
                .environmentObject(paintingVM)
                .environmentObject(recipeVM)
                .environmentObject(resourcepackVM)
                .onAppear {
                    canvasVM.connect(to: blockVM)
                    canvasVM.connect(to: itemVM)
                    canvasVM.connect(to: skinVM)
                    canvasVM.connect(to: paintingVM)
                    exportVM.connect(to: blockVM)
                    exportVM.connect(to: itemVM)
                    blockVM.startAutosave()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .inactive || newPhase == .background {
                        blockVM.autosave()
                    }
                }
                // MARK: - Speichern unter
                .fileExporter(
                    isPresented: $showSaveDialog,
                    document: documentToSave,
                    contentType: UTType(filenameExtension: "voxel") ?? .json,
                    defaultFilename: "\(blockVM.project.name).voxel"
                ) { result in
                    switch result {
                    case .success(let url):
                        blockVM.currentFileURL = url
                        blockVM.project.name = url.deletingPathExtension().lastPathComponent
                    case .failure(let error):
                        print("Speichern fehlgeschlagen: \(error.localizedDescription)")
                    }
                }
                // MARK: - Öffnen
                .fileImporter(
                    isPresented: $showOpenDialog,
                    allowedContentTypes: [UTType(filenameExtension: "voxel") ?? .json],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        do {
                            try blockVM.loadProject(from: url)
                            canvasVM.resetUndoHistory()
                        } catch {
                            print("Öffnen fehlgeschlagen: \(error.localizedDescription)")
                        }
                    case .failure(let error):
                        print("Öffnen fehlgeschlagen: \(error.localizedDescription)")
                    }
                }
        }
        .commands {
            // MARK: - Datei-Menü

            CommandGroup(replacing: .newItem) {
                Button("Neues Projekt") {
                    blockVM.newProject()
                    canvasVM.resetUndoHistory()
                }
                .keyboardShortcut("n")

                Button("Öffnen…") {
                    showOpenDialog = true
                }
                .keyboardShortcut("o")

                Divider()

                Button("Speichern") {
                    saveFile()
                }
                .keyboardShortcut("s")

                Button("Speichern unter…") {
                    saveFileAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("Face PNGs exportieren…") {
                    exportVM.exportFacePNGs()
                }
                .disabled(exportVM.isExporting)

                Button("Resourcepack exportieren…") {
                    exportVM.exportResourcepack()
                }
                .disabled(exportVM.isExporting)
            }

            // MARK: - Bearbeiten-Menü

            CommandGroup(replacing: .undoRedo) {
                Button("Rückgängig") {
                    canvasVM.undo()
                }
                .keyboardShortcut("z")
                .disabled(!canvasVM.canUndo)

                Button("Wiederherstellen") {
                    canvasVM.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!canvasVM.canRedo)
            }

            // MARK: - Block-Menü

            CommandMenu("Block") {
                ForEach(FaceType.allCases) { face in
                    Button("Face: \(face.rawValue)") {
                        canvasVM.resetUndoHistory()
                        blockVM.selectFace(face)
                    }
                }

                Divider()

                Button("Face leeren") {
                    canvasVM.clearCanvas()
                }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])

                Divider()

                Button("Nächstes Face") {
                    canvasVM.resetUndoHistory()
                    blockVM.nextFace()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                Button("Vorheriges Face") {
                    canvasVM.resetUndoHistory()
                    blockVM.previousFace()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
            }
        }
    }

    // MARK: - Datei-Operationen

    private func saveFile() {
        if let url = blockVM.currentFileURL {
            do {
                try blockVM.saveProject(to: url)
            } catch {
                saveFileAs()
            }
        } else {
            saveFileAs()
        }
    }

    private func saveFileAs() {
        let file = VoxelProjectFile(from: blockVM.project)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(file) else {
            print("Speichern fehlgeschlagen: Projekt konnte nicht kodiert werden")
            return
        }
        documentToSave = VoxelDocument(data: data)
        showSaveDialog = true
    }
}
