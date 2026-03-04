//
//  ContentView.swift
//  VoxelSprite
//
//  Root View der App.
//  Links: Canvas mit Tools + Farbpalette + Animation-Timeline
//  Rechts: Vollhöhe-Sidebar mit Modus-Umschaltung, Selektoren, 3D-Vorschau, Export
//

import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Einheitliche Akzentfarbe — Electric Teal
let accentTeal = Color(red: 0.0, green: 0.85, blue: 0.85)

struct ContentView: View {

    @EnvironmentObject var blockVM: BlockViewModel
    @EnvironmentObject var canvasVM: CanvasViewModel
    @EnvironmentObject var exportVM: ExportViewModel
    @EnvironmentObject var itemVM: ItemViewModel
    @EnvironmentObject var skinVM: SkinViewModel

    @State private var showSaveDialog = false
    @State private var showOpenDialog = false
    @State private var documentToSave: VoxelDocument?
    @State private var showTilePreview = false
    @State private var show3DGrid = true

    var body: some View {
        mainContent
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 640)
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

    // MARK: - Hauptlayout: Sidebar reicht bis oben

    private var innerContent: some View {
        HStack(spacing: 0) {

            // MARK: - Linke Seite: Canvas-Bereich
            VStack(spacing: 12) {
                ToolBarView()

                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    PixelCanvasView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Animation Timeline (nur im Block-Modus)
                if canvasVM.editorMode == .block {
                    AnimationTimelineView()
                }

                ColorPaletteView()
            }
            .padding(16)

            // Trennlinie
            Rectangle()
                .fill(.quaternary)
                .frame(width: 1)

            // MARK: - Rechte Seite: Vollhöhe-Sidebar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {

                    // MARK: - Modus-Umschaltung
                    modeSwitcher

                    Divider()

                    // MARK: - Modus-spezifischer Inhalt
                    switch canvasVM.editorMode {
                    case .block:
                        blockSidebarContent
                    case .item:
                        itemSidebarContent
                    case .skin:
                        skinSidebarContent
                    }

                    Divider()

                    // MARK: - Face / Layer Overlay (Shared)
                    overlaySection

                    Divider()

                    // MARK: - Export
                    switch canvasVM.editorMode {
                    case .block:
                        exportCard
                    case .item:
                        itemExportCard
                    case .skin:
                        skinExportCard
                    }
                }
                .padding(16)
            }
            .frame(width: 320)
            .background(.background.opacity(0.5))
        }
    }

    // MARK: - Modus-Umschaltung

    private var modeSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(CanvasViewModel.EditorMode.allCases) { mode in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        canvasVM.editorMode = mode
                        canvasVM.resetUndoHistory()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 13, weight: .semibold))
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(canvasVM.editorMode == mode ? accentTeal.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(canvasVM.editorMode == mode ? accentTeal.opacity(0.6) : .white.opacity(0.08), lineWidth: canvasVM.editorMode == mode ? 1.5 : 1)
                    )
                    .foregroundStyle(canvasVM.editorMode == mode ? accentTeal : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Block Sidebar

    @ViewBuilder
    private var blockSidebarContent: some View {
        // Face-Selector (kompakt)
        FaceSelectorView()

        Divider()

        // Block-Einstellungen
        sectionHeader("BLOCK")

        // Block-Name
        HStack {
            Text("Name:")
                .font(.system(size: 11, weight: .medium))
            TextField("block_name", text: $blockVM.project.name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .controlSize(.small)
        }

        // Canvas-Größe
        HStack(spacing: 6) {
            ForEach(PixelCanvas.PresetSize.allCases) { preset in
                Button {
                    blockVM.newProject(gridSize: preset.rawValue)
                    canvasVM.resetUndoHistory()
                } label: {
                    Text(preset.label)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(blockVM.project.gridSize == preset.rawValue ? accentTeal : nil)
            }
        }

        // Template-Auswahl
        HStack(spacing: 4) {
            ForEach(BlockTemplate.allCases) { template in
                Button {
                    blockVM.project.template = template
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: template.iconName)
                            .font(.system(size: 12))
                        Text(template.rawValue)
                            .font(.system(size: 8, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(blockVM.project.template == template ? accentTeal : nil)
            }
        }

        Divider()

        // MARK: - Rotation
        rotationSection

        Divider()

        // MARK: - CTM
        ctmSection

        Divider()

        // MARK: - Animation Settings (wenn Face animiert)
        if blockVM.activeFace.isAnimated && blockVM.project.ctmMethod == .none {
            animationSettingsSection
            Divider()
        }

        // 3D Vorschau (SceneKit)
        HStack {
            sectionHeader("3D VORSCHAU")
            Spacer()
            Toggle(isOn: $show3DGrid) {
                Image(systemName: "grid")
                    .font(.system(size: 10, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.mini)
            .help("Pixel-Grid auf 3D-Modell")
        }

        SceneKitPreviewView(showGrid: show3DGrid)

        Divider()

        // Tile-Vorschau
        Toggle("Tile-Vorschau (3×3)", isOn: $showTilePreview)
            .font(.system(size: 11, weight: .medium))
            .toggleStyle(.switch)
            .controlSize(.small)

        if showTilePreview {
            TilePreviewView(faceType: blockVM.activeFaceType)
        }
    }

    // MARK: - Rotation Section

    private var rotationSection: some View {
        VStack(spacing: 8) {
            sectionHeader("ROTATION")

            HStack(spacing: 4) {
                ForEach(BlockRotation.allCases) { rotation in
                    Button {
                        blockVM.project.rotation = rotation
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: rotation.iconName)
                                .font(.system(size: 12))
                            Text(rotation.rawValue)
                                .font(.system(size: 7, weight: .medium))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(blockVM.project.rotation == rotation ? accentTeal : nil)
                }
            }

            if blockVM.project.rotation != .none {
                Text(blockVM.project.rotation.description)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - CTM Section

    private var ctmSection: some View {
        VStack(spacing: 8) {
            sectionHeader("CONNECTED TEXTURES")

            HStack(spacing: 4) {
                ForEach(CTMMethod.allCases) { method in
                    Button {
                        blockVM.project.ctmMethod = method
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: method.iconName)
                                .font(.system(size: 12))
                            Text(method.rawValue)
                                .font(.system(size: 8, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(blockVM.project.ctmMethod == method ? accentTeal : nil)
                }
            }

            if blockVM.project.ctmMethod != .none {
                Text(blockVM.project.ctmMethod.description)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)

                // CTM Repeat Dimensionen
                if blockVM.project.ctmMethod == .repeat_ {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("W:")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Stepper(value: $blockVM.project.ctmRepeatWidth, in: 1...8) {
                                Text("\(blockVM.project.ctmRepeatWidth)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(accentTeal)
                            }
                            .controlSize(.mini)
                        }
                        HStack(spacing: 4) {
                            Text("H:")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Stepper(value: $blockVM.project.ctmRepeatHeight, in: 1...8) {
                                Text("\(blockVM.project.ctmRepeatHeight)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(accentTeal)
                            }
                            .controlSize(.mini)
                        }
                    }
                }

                // Info: Frames werden als Tiles/Varianten verwendet
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9))
                    Text(blockVM.project.ctmMethod == .random
                         ? "Frames = Zufällige Varianten"
                         : "Frames = Tiles im \(blockVM.project.ctmRepeatWidth)×\(blockVM.project.ctmRepeatHeight) Muster")
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Animation Settings

    private var animationSettingsSection: some View {
        VStack(spacing: 8) {
            sectionHeader("ANIMATION")

            // Frame Time
            HStack {
                Text("Frame-Zeit:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(
                    value: Binding(
                        get: { blockVM.activeFace.frameTime },
                        set: { blockVM.project.faces[blockVM.activeFaceType]?.frameTime = $0 }
                    ),
                    in: 1...100
                ) {
                    Text("\(blockVM.activeFace.frameTime) Ticks")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentTeal)
                }
                .controlSize(.mini)
            }

            // Geschwindigkeit Info
            let seconds = Double(blockVM.activeFace.frameTime) / 20.0
            Text(String(format: "%.2f Sek./Frame · %.1f FPS", seconds, 1.0 / seconds))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)

            // Interpolation
            Toggle("Interpolation", isOn: Binding(
                get: { blockVM.activeFace.interpolate },
                set: { blockVM.project.faces[blockVM.activeFaceType]?.interpolate = $0 }
            ))
            .font(.system(size: 11, weight: .medium))
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    // MARK: - Item Sidebar

    @ViewBuilder
    private var itemSidebarContent: some View {
        // Item-Einstellungen
        sectionHeader("ITEM")

        // Item-Name
        HStack {
            Text("Name:")
                .font(.system(size: 11, weight: .medium))
            TextField("item_name", text: $itemVM.project.name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .controlSize(.small)
        }

        // Canvas-Größe
        HStack(spacing: 6) {
            ForEach(PixelCanvas.PresetSize.allCases) { preset in
                Button {
                    itemVM.newProject(gridSize: preset.rawValue)
                    canvasVM.resetUndoHistory()
                } label: {
                    Text(preset.label)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(itemVM.project.gridSize == preset.rawValue ? accentTeal : nil)
            }
        }

        // Display-Typ
        sectionHeader("DISPLAY")

        HStack(spacing: 4) {
            ForEach(ItemDisplayType.allCases) { displayType in
                Button {
                    itemVM.project.displayType = displayType
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: displayType.iconName)
                            .font(.system(size: 14))
                        Text(displayType.rawValue)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(itemVM.project.displayType == displayType ? accentTeal : nil)
            }
        }

        Text(itemVM.project.displayType.description)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.tertiary)

        Divider()

        // Layer-Verwaltung
        itemLayerSection

        Divider()

        // 3D Vorschau
        HStack {
            sectionHeader("3D VORSCHAU")
            Spacer()
            Toggle(isOn: $show3DGrid) {
                Image(systemName: "grid")
                    .font(.system(size: 10, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.mini)
            .help("Pixel-Grid auf 3D-Modell")
        }

        ItemPreviewView(showGrid: show3DGrid)
    }

    // MARK: - Item Layer Section

    private var itemLayerSection: some View {
        VStack(spacing: 8) {
            HStack {
                sectionHeader("LAYER")
                Spacer()

                // Layer hinzufügen
                Button {
                    canvasVM.resetUndoHistory()
                    itemVM.addLayer()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(accentTeal)
                .help("Layer hinzufügen")
            }

            // Layer-Liste
            ForEach(0..<itemVM.project.layers.count, id: \.self) { index in
                HStack(spacing: 6) {
                    // Layer-Thumbnail
                    let canvas = itemVM.project.layers[index]
                    if let cgImage = canvas.toCGImage() {
                        #if os(macOS)
                        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: canvas.width, height: canvas.height))
                        Image(nsImage: nsImage)
                            .resizable()
                            .interpolation(.none)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        #elseif os(iOS)
                        Image(uiImage: UIImage(cgImage: cgImage))
                            .resizable()
                            .interpolation(.none)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        #endif
                    }

                    Text("layer\(index)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(index == itemVM.activeLayerIndex ? accentTeal : .secondary)

                    Spacer()

                    // Layer löschen
                    if itemVM.project.layers.count > 1 {
                        Button {
                            canvasVM.resetUndoHistory()
                            itemVM.deleteLayer()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.6))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(index == itemVM.activeLayerIndex ? accentTeal.opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(index == itemVM.activeLayerIndex ? accentTeal.opacity(0.5) : .clear, lineWidth: 1)
                )
                .onTapGesture {
                    canvasVM.resetUndoHistory()
                    itemVM.selectLayer(index)
                }
            }

            if itemVM.project.isMultiLayer {
                Text("Layer 0 = hinten, höhere Layer = vorne")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Item Export Card

    private var itemExportCard: some View {
        VStack(spacing: 10) {
            sectionHeader("EXPORT")

            // Ziel-Version
            Picker("Version:", selection: $itemVM.project.targetVersion) {
                ForEach(BlockProject.TargetVersion.allCases) { version in
                    Text(version.shortLabel).tag(version)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.mini)

            // Namespace
            HStack {
                Text("Namespace:")
                    .font(.system(size: 10, weight: .medium))
                TextField("minecraft", text: $itemVM.project.namespace)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10, design: .monospaced))
                    .controlSize(.small)
            }

            // Transparenter Hintergrund
            Toggle("Transparenter Hintergrund", isOn: $exportVM.transparentBackground)
                .font(.system(size: 11))
                .toggleStyle(.switch)
                .controlSize(.small)

            // Export-Info
            if itemVM.project.isMultiLayer {
                exportBadge("\(itemVM.project.layerCount) Layer", icon: "square.stack", color: .blue)
            }

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
                    exportVM.exportItemPNG()
                } label: {
                    Label("Item PNG", systemImage: "photo")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentTeal)
                .disabled(exportVM.isExporting)

                Button {
                    exportVM.exportItemResourcepack()
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

    // MARK: - Skin Sidebar

    @ViewBuilder
    private var skinSidebarContent: some View {
        // Body Part Selector
        BodyPartSelectorView()

        Divider()

        // 3D Vorschau
        HStack {
            sectionHeader("3D VORSCHAU")
            Spacer()
            Toggle(isOn: $show3DGrid) {
                Image(systemName: "grid")
                    .font(.system(size: 10, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.mini)
            .help("Pixel-Grid auf 3D-Modell")
        }

        StevePreviewView(showGrid: show3DGrid)
    }

    // MARK: - Overlay Section (Block + Skin)

    @ViewBuilder
    private var overlaySection: some View {
        sectionHeader(canvasVM.editorMode == .block ? "FACE OVERLAY" : "LAYER OVERLAY")

        Toggle(canvasVM.editorMode == .block ? "Face Overlay" : "Layer Overlay",
               isOn: $canvasVM.faceOverlayEnabled)
            .font(.system(size: 11, weight: .medium))
            .toggleStyle(.switch)
            .controlSize(.small)

        if canvasVM.faceOverlayEnabled {
            if canvasVM.editorMode == .block {
                // Face Picker für Block-Modus
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
            } else if canvasVM.editorMode == .item {
                // Item-Modus: Overlay zeigt andere Layer
                Text("Zeigt andere Layer")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            } else {
                // Skin-Modus: Overlay zeigt automatisch den anderen Layer
                Text(skinVM.activeLayer == .base ? "Zeigt Overlay-Layer" : "Zeigt Base-Layer")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Text("Opacity")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Slider(value: $canvasVM.faceOverlayOpacity, in: 0.05...0.8)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Block Export Card

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
                    .font(.system(size: 10, weight: .medium))
                TextField("minecraft", text: $blockVM.project.namespace)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10, design: .monospaced))
                    .controlSize(.small)
            }

            // Transparenter Hintergrund
            Toggle("Transparenter Hintergrund", isOn: $exportVM.transparentBackground)
                .font(.system(size: 11))
                .toggleStyle(.switch)
                .controlSize(.small)

            // Export-Info
            exportInfoBadges

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

    // MARK: - Export Info Badges

    @ViewBuilder
    private var exportInfoBadges: some View {
        let hasAnimation = blockVM.project.hasAnimatedFaces && blockVM.project.ctmMethod == .none
        let hasRotation = blockVM.project.rotation != .none
        let hasCTM = blockVM.project.ctmMethod != .none

        if hasAnimation || hasRotation || hasCTM {
            HStack(spacing: 4) {
                if hasAnimation {
                    exportBadge("Animiert", icon: "film", color: .orange)
                }
                if hasRotation {
                    exportBadge(blockVM.project.rotation.rawValue, icon: blockVM.project.rotation.iconName, color: .purple)
                }
                if hasCTM {
                    exportBadge("CTM \(blockVM.project.ctmMethod.rawValue)", icon: blockVM.project.ctmMethod.iconName, color: .green)
                }
            }
        }
    }

    private func exportBadge(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 8, weight: .bold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.15))
        )
        .foregroundStyle(color)
    }

    // MARK: - Skin Export Card

    private var skinExportCard: some View {
        VStack(spacing: 10) {
            sectionHeader("EXPORT")

            HStack {
                Text("Skin-Name:")
                    .font(.system(size: 11, weight: .medium))
                TextField("steve", text: $skinVM.project.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .controlSize(.small)
            }

            Button {
                exportSkinPNG()
            } label: {
                Label("Skin PNG (64×64)", systemImage: "photo")
                    .font(.system(size: 11, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(accentTeal)
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

    // MARK: - Skin PNG Export

    private func exportSkinPNG() {
        let composited = skinVM.project.composited()
        guard let cgImage = composited.toCGImage() else { return }

        #if canImport(AppKit)
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = rep.representation(using: .png, properties: [:]) else { return }
        #elseif canImport(UIKit)
        guard let pngData = UIImage(cgImage: cgImage).pngData() else { return }
        #else
        return
        #endif

        let fileName = "\(skinVM.project.name).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? pngData.write(to: url, options: .atomic)

        exportVM.exportedFileURL = url
        exportVM.showShareSheet = true
    }

    // MARK: - Subviews

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
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
