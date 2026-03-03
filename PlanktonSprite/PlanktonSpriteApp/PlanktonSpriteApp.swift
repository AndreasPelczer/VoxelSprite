//
//  PlanktonSpriteApp.swift
//  PlanktonSpriteApp
//
//  Created by Andreas Pelczer on 27.02.26.
//


import SwiftUI
import UniformTypeIdentifiers

/// Entry Point der App.
/// Hier werden alle ViewModels erzeugt und miteinander verbunden.
/// Enthält die macOS-Menüleiste (Datei/Bearbeiten/Bild).
@main
struct PlanktonSpriteApp: App {

    // MARK: - ViewModels

    /// Die ViewModels als @StateObject – sie leben so lange wie die App.
    @StateObject private var frameVM = FrameViewModel()
    @StateObject private var canvasVM = CanvasViewModel()
    @StateObject private var exportVM = ExportViewModel()
    @StateObject private var paletteManager = PaletteManager()

    /// Reagiert auf App-Lifecycle (Background, Inactive)
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Datei-Dialog State

    /// Steuert ob der "Speichern unter"-Dialog angezeigt wird
    @State private var showSaveDialog = false

    /// Steuert ob der "Öffnen"-Dialog angezeigt wird
    @State private var showOpenDialog = false

    /// Das Dokument das gespeichert werden soll (wird vor dem Dialog erstellt)
    @State private var documentToSave: PlanktonDocument?

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(frameVM)
                .environmentObject(canvasVM)
                .environmentObject(exportVM)
                .environmentObject(paletteManager)
                .onAppear {
                    canvasVM.connect(to: frameVM)
                    exportVM.connect(to: frameVM)
                    frameVM.startAutosave()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .inactive || newPhase == .background {
                        frameVM.autosave()
                    }
                }
                // MARK: - Speichern unter (plattformübergreifend)
                .fileExporter(
                    isPresented: $showSaveDialog,
                    document: documentToSave,
                    contentType: UTType(filenameExtension: "plankton") ?? .json,
                    defaultFilename: "\(frameVM.project.name).plankton"
                ) { result in
                    switch result {
                    case .success(let url):
                        frameVM.currentFileURL = url
                        frameVM.project.name = url.deletingPathExtension().lastPathComponent
                    case .failure(let error):
                        print("Speichern fehlgeschlagen: \(error.localizedDescription)")
                    }
                }
                // MARK: - Öffnen (plattformübergreifend)
                .fileImporter(
                    isPresented: $showOpenDialog,
                    allowedContentTypes: [UTType(filenameExtension: "plankton") ?? .json],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        do {
                            try frameVM.loadProject(from: url)
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
                    frameVM.newProject()
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

                Button("GIF exportieren…") {
                    exportVM.exportGIF()
                }
                .disabled(exportVM.isExporting)

                Button("PNG Spritesheet exportieren…") {
                    exportVM.exportSpritesheet()
                }
                .disabled(exportVM.isExporting)
            }

            // MARK: - Bearbeiten-Menü (Undo/Redo)

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

            // MARK: - Bild-Menü

            CommandMenu("Bild") {
                Button("Neuer Frame") {
                    frameVM.addFrame()
                }
                .keyboardShortcut("f", modifiers: [.command])
                .disabled(!frameVM.canAddFrame)

                Button("Frame kopieren") {
                    frameVM.duplicateActiveFrame()
                }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(!frameVM.canAddFrame)

                Button("Frame löschen") {
                    frameVM.deleteActiveFrame()
                }
                .keyboardShortcut(.delete, modifiers: [.command])
                .disabled(frameVM.frameCount <= 1)

                Divider()

                Button("Canvas leeren") {
                    canvasVM.clearCanvas()
                }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
            }
        }
    }

    // MARK: - Datei-Operationen

    /// Speichern: wenn schon ein Pfad bekannt ist, direkt überschreiben.
    /// Sonst "Speichern unter" aufrufen.
    private func saveFile() {
        if let url = frameVM.currentFileURL {
            do {
                try frameVM.saveProject(to: url)
            } catch {
                // Direktes Speichern fehlgeschlagen → Dialog zeigen
                saveFileAs()
            }
        } else {
            saveFileAs()
        }
    }

    /// Speichern unter: Projekt als JSON kodieren und Dialog anzeigen
    private func saveFileAs() {
        let file = ProjectFile(from: frameVM.project)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(file) else {
            print("Speichern fehlgeschlagen: Projekt konnte nicht kodiert werden")
            return
        }
        documentToSave = PlanktonDocument(data: data)
        showSaveDialog = true
    }
}
