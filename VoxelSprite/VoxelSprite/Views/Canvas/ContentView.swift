//
//  ContentView.swift
//  VoxelSprite
//
//  Root View der App.
//  Links: Face-Selector + Canvas mit Tools
//  Rechts: 3D-Vorschau + Export
//

import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

/// Einheitliche Akzentfarbe — Electric Teal
let accentTeal = Color(red: 0.0, green: 0.85, blue: 0.85)

struct ContentView: View {

    @EnvironmentObject var blockVM: BlockViewModel
    @EnvironmentObject var canvasVM: CanvasViewModel
    @EnvironmentObject var exportVM: ExportViewModel

    @State private var showSaveDialog = false
    @State private var showOpenDialog = false
    @State private var documentToSave: VoxelDocument?
    @State private var showTilePreview = false

    var body: some View {
        mainContent
        #if os(macOS)
        .frame(minWidth: 850, minHeight: 620)
        #endif
        .background(Color(red: 0.1, green: 0.1, blue: 0.14))
        .preferredColorScheme(.dark)
        .keyboardShortcut("z", modifiers: .command, action: canvasVM.undo)
        .keyboardShortcut("z", modifiers: [.command, .shift], action: canvasVM.redo)
        // Share Sheet (Export)
        .sheet(isPresented: $exportVM.showShareSheet) {
            exportVM.cleanup()
        } content: {
            if let url = exportVM.exportedFileURL {
                #if os(iOS)
                ShareSheetView(activityItems: [url])
                #else
                VStack(spacing: 16) {
                    Text("Exportiert!")
                        .font(.headline)
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("OK") { exportVM.cleanup() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(40)
                #endif
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        #if os(iOS)
        NavigationStack {
            innerContent
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button {
                            blockVM.newProject()
                            canvasVM.resetUndoHistory()
                        } label: {
                            Label("Neu", systemImage: "doc.badge.plus")
                        }

                        Button {
                            showOpenDialog = true
                        } label: {
                            Label("Öffnen", systemImage: "folder")
                        }

                        Button {
                            saveFile()
                        } label: {
                            Label("Speichern", systemImage: "square.and.arrow.down")
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .fileExporter(
                    isPresented: $showSaveDialog,
                    document: documentToSave,
                    contentType: UTType(filenameExtension: "voxel") ?? .json,
                    defaultFilename: "\(blockVM.project.name).voxel"
                ) { result in
                    if case .success(let url) = result {
                        blockVM.currentFileURL = url
                        blockVM.project.name = url.deletingPathExtension().lastPathComponent
                    }
                }
                .fileImporter(
                    isPresented: $showOpenDialog,
                    allowedContentTypes: [UTType(filenameExtension: "voxel") ?? .json],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        try? blockVM.loadProject(from: url)
                        canvasVM.resetUndoHistory()
                    }
                }
        }
        #else
        innerContent
        #endif
    }

    private var innerContent: some View {
        VStack(spacing: 0) {

            // MARK: - Oben: Face-Selector

            FaceSelectorView()

            // Trennlinie
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)

            // MARK: - Unten: Canvas + Preview

            HStack(spacing: 0) {

                // Linke Seite: Canvas-Bereich
                VStack(spacing: 12) {
                    ToolBarView()
                    PixelCanvasView()
                    ColorPaletteView()
                }
                .padding(16)

                // Trennlinie
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 1)

                // Rechte Seite: Vorschau + Export
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {

                        // MARK: - Block-Einstellungen
                        sectionHeader("BLOCK")

                        // Block-Name
                        HStack {
                            Text("Name:")
                                .font(.system(size: 10, weight: .medium))
                            TextField("block_name", text: $blockVM.project.name)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 10, design: .monospaced))
                                .controlSize(.mini)
                        }

                        // Canvas-Größe
                        HStack(spacing: 4) {
                            ForEach(PixelCanvas.PresetSize.allCases) { preset in
                                Button {
                                    blockVM.newProject(gridSize: preset.rawValue)
                                    canvasVM.resetUndoHistory()
                                } label: {
                                    Text(preset.label)
                                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .tint(blockVM.project.gridSize == preset.rawValue ? accentTeal : nil)
                            }
                        }

                        // Template-Auswahl
                        HStack(spacing: 4) {
                            ForEach(BlockTemplate.allCases) { template in
                                Button {
                                    blockVM.project.template = template
                                } label: {
                                    VStack(spacing: 2) {
                                        Image(systemName: template.iconName)
                                            .font(.system(size: 10))
                                        Text(template.rawValue)
                                            .font(.system(size: 7, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .tint(blockVM.project.template == template ? accentTeal : nil)
                            }
                        }

                        Divider()

                        // MARK: - 3D Vorschau
                        sectionHeader("3D VORSCHAU")

                        IsometricPreviewView()

                        Divider()

                        // MARK: - Tile-Vorschau
                        Toggle("Tile-Vorschau (3×3)", isOn: $showTilePreview)
                            .font(.system(size: 10, weight: .medium))
                            .toggleStyle(.switch)
                            .controlSize(.mini)

                        if showTilePreview {
                            TilePreviewView(faceType: blockVM.activeFaceType)
                        }

                        Divider()

                        // MARK: - Face Overlay
                        sectionHeader("FACE OVERLAY")

                        Toggle("Face Overlay", isOn: $canvasVM.faceOverlayEnabled)
                            .font(.system(size: 10, weight: .medium))
                            .toggleStyle(.switch)
                            .controlSize(.mini)

                        if canvasVM.faceOverlayEnabled {
                            // Overlay Face Picker
                            Picker("Face:", selection: Binding(
                                get: { canvasVM.overlayFaceType ?? canvasVM.oppositeFaceType ?? .south },
                                set: { canvasVM.overlayFaceType = $0 }
                            )) {
                                ForEach(FaceType.allCases) { face in
                                    Text(face.rawValue).tag(face)
                                }
                            }
                            .pickerStyle(.menu)
                            .controlSize(.mini)

                            HStack {
                                Text("Opacity")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                Slider(value: $canvasVM.faceOverlayOpacity, in: 0.05...0.8)
                                    .controlSize(.small)
                            }
                        }

                        Divider()

                        // MARK: - Export (Card-Design)
                        exportCard
                    }
                    .padding(12)
                }
                .frame(width: 260)
                .background(.background.opacity(0.5))
            }
        }
    }

    // MARK: - Export Card

    private var exportCard: some View {
        VStack(spacing: 10) {
            sectionHeader("EXPORT")

            // Ziel-Version
            Picker("Version:", selection: $blockVM.project.targetVersion) {
                ForEach(BlockProject.TargetVersion.allCases) { version in
                    Text(version.shortLabel).tag(version)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.mini)

            // Namespace
            HStack {
                Text("Namespace:")
                    .font(.system(size: 9, weight: .medium))
                TextField("minecraft", text: $blockVM.project.namespace)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 9, design: .monospaced))
                    .controlSize(.mini)
            }

            // Transparenter Hintergrund
            Toggle("Transparenter Hintergrund", isOn: $exportVM.transparentBackground)
                .font(.system(size: 10))
                .toggleStyle(.switch)
                .controlSize(.mini)

            // Export-Fortschritt
            if exportVM.isExporting {
                VStack(spacing: 4) {
                    ProgressView(value: exportVM.exportProgress)
                        .progressViewStyle(.linear)
                        .tint(accentTeal)
                    Text(exportVM.exportStatus)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            // Export-Buttons
            VStack(spacing: 6) {
                Button {
                    exportVM.exportFacePNGs()
                } label: {
                    Label("Face PNGs", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentTeal)
                .disabled(exportVM.isExporting)

                Button {
                    exportVM.exportResourcepack()
                } label: {
                    Label("Resourcepack", systemImage: "shippingbox")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentTeal.opacity(0.7))
                .disabled(exportVM.isExporting)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accentTeal.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Subviews

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - iPad Save

    #if os(iOS)
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
        guard let data = try? encoder.encode(file) else { return }
        documentToSave = VoxelDocument(data: data)
        showSaveDialog = true
    }
    #endif
}

// MARK: - Share Sheet (iOS)

#if os(iOS)
struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Keyboard Shortcut Extension

extension View {
    func keyboardShortcut(
        _ key: KeyEquivalent,
        modifiers: EventModifiers,
        action: @escaping () -> Void
    ) -> some View {
        self.background(
            Button("", action: action)
                .keyboardShortcut(key, modifiers: modifiers)
                .hidden()
        )
    }
}
