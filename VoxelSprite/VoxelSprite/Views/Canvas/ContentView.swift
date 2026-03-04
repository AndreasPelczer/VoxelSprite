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
    @EnvironmentObject var paintingVM: PaintingViewModel
    @EnvironmentObject var recipeVM: RecipeViewModel
    @EnvironmentObject var resourcepackVM: ResourcepackViewModel
    @EnvironmentObject var entityVM: EntityViewModel
    @EnvironmentObject var armorVM: ArmorViewModel

    @State private var showSaveDialog = false
    @State private var showOpenDialog = false
    @State private var documentToSave: VoxelDocument?
    @State private var showTilePreview = false
    @State private var show3DGrid = true
    @State private var paint3DEnabled = false

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
                if canvasVM.editorMode == .recipe {
                    // Rezept-Modus: Kein Canvas, stattdessen Grid
                    RecipeGridView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ToolBarView()

                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        PixelCanvasView()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // MARK: - Statusleiste
                    canvasStatusBar

                    // Animation Timeline (nur im Block-Modus)
                    if canvasVM.editorMode == .block {
                        AnimationTimelineView()
                    }

                    ColorPaletteView()
                }
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
                    case .painting:
                        paintingSidebarContent
                    case .recipe:
                        recipeSidebarContent
                    case .entity:
                        entitySidebarContent
                    case .armor:
                        armorSidebarContent
                    }

                    Divider()

                    // MARK: - Face / Layer Overlay (Shared, nicht für Recipe)
                    if canvasVM.editorMode != .recipe {
                        overlaySection
                        Divider()
                    }

                    // MARK: - Export
                    switch canvasVM.editorMode {
                    case .block:
                        exportCard
                    case .item:
                        itemExportCard
                    case .skin:
                        skinExportCard
                    case .painting:
                        paintingExportCard
                    case .recipe:
                        recipeExportCard
                    case .entity:
                        entityExportCard
                    case .armor:
                        armorExportCard
                    }

                    Divider()

                    // MARK: - Resourcepack (immer sichtbar)
                    resourcepackSection
                }
                .padding(16)
            }
            .frame(width: 320)
            .background(.background.opacity(0.5))
        }
    }

    // MARK: - Modus-Umschaltung

    private var modeSwitcher: some View {
        VStack(spacing: 4) {
            // Erste Reihe: Block, Item, Andy
            HStack(spacing: 4) {
                ForEach([CanvasViewModel.EditorMode.block, .item, .skin], id: \.self) { mode in
                    modeButton(mode)
                }
            }
            // Zweite Reihe: Painting, Rezept
            HStack(spacing: 4) {
                ForEach([CanvasViewModel.EditorMode.painting, .recipe], id: \.self) { mode in
                    modeButton(mode)
                }
            }
            // Dritte Reihe: Entity, Armor
            HStack(spacing: 4) {
                ForEach([CanvasViewModel.EditorMode.entity, .armor], id: \.self) { mode in
                    modeButton(mode)
                }
            }
        }
    }

    private func modeButton(_ mode: CanvasViewModel.EditorMode) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                canvasVM.editorMode = mode
                canvasVM.resetUndoHistory()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 11, weight: .semibold))
                Text(mode.rawValue)
                    .font(.system(size: 11, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(canvasVM.editorMode == mode ? accentTeal.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(canvasVM.editorMode == mode ? accentTeal.opacity(0.6) : .white.opacity(0.08), lineWidth: canvasVM.editorMode == mode ? 1.5 : 1)
            )
            .foregroundStyle(canvasVM.editorMode == mode ? accentTeal : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Statusleiste

    private var canvasStatusBar: some View {
        HStack(spacing: 12) {
            // Aktives Werkzeug
            HStack(spacing: 4) {
                Image(systemName: canvasVM.currentTool.iconName)
                    .font(.system(size: 9, weight: .medium))
                Text(canvasVM.currentTool.rawValue)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(accentTeal.opacity(0.8))

            Divider().frame(height: 10)

            // Canvas-Größe
            Text("\(canvasVM.canvasWidth)×\(canvasVM.canvasHeight) px")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

            Divider().frame(height: 10)

            // Cursor-Position
            if let cx = canvasVM.cursorX, let cy = canvasVM.cursorY {
                Text("X: \(cx)  Y: \(cy)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Text("X: -  Y: -")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }

            // Selection-Größe
            if let sel = canvasVM.selection {
                Divider().frame(height: 10)
                Text("Sel: \(sel.width)×\(sel.height)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(accentTeal.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
            Toggle(isOn: $paint3DEnabled) {
                Image(systemName: "paintbrush")
                    .font(.system(size: 10, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.mini)
            .tint(paint3DEnabled ? accentTeal : nil)
            .help("Direkt auf 3D-Modell malen")
            Toggle(isOn: $show3DGrid) {
                Image(systemName: "grid")
                    .font(.system(size: 10, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.mini)
            .help("Pixel-Grid auf 3D-Modell")
        }

        SceneKitPreviewView(showGrid: show3DGrid, paintEnabled: paint3DEnabled)

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

            // Item Preflight Warnings
            let itemWarnings = exportVM.runItemPreflight(project: itemVM.project)
            let itemHasErrors = itemWarnings.contains { $0.severity == .error }
            if !itemWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(itemWarnings) { warning in
                        HStack(spacing: 4) {
                            Image(systemName: warning.severity.iconName)
                                .font(.system(size: 8))
                                .foregroundStyle(warning.severity.color)
                            Text(warning.message)
                                .font(.system(size: 9))
                                .foregroundStyle(warning.severity == .info ? .secondary : .primary)
                        }
                    }
                }
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
                .disabled(exportVM.isExporting || itemHasErrors)

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
                .disabled(exportVM.isExporting || itemHasErrors)
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
            Toggle(isOn: $paint3DEnabled) {
                Image(systemName: "paintbrush")
                    .font(.system(size: 10, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.mini)
            .tint(paint3DEnabled ? accentTeal : nil)
            .help("Direkt auf 3D-Modell malen")
            Toggle(isOn: $show3DGrid) {
                Image(systemName: "grid")
                    .font(.system(size: 10, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.mini)
            .help("Pixel-Grid auf 3D-Modell")
        }

        AndyPreviewView(showGrid: show3DGrid, paintEnabled: paint3DEnabled)
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

            // Preflight Warnings
            let preflightWarnings = exportVM.runPreflight(project: blockVM.project)
            let hasErrors = preflightWarnings.contains { $0.severity == .error }
            if !preflightWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(preflightWarnings) { warning in
                        HStack(spacing: 4) {
                            Image(systemName: warning.severity.iconName)
                                .font(.system(size: 8))
                                .foregroundStyle(warning.severity.color)
                            Text(warning.message)
                                .font(.system(size: 9))
                                .foregroundStyle(warning.severity == .info ? .secondary : .primary)
                        }
                    }
                }
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
                    exportVM.exportFacePNGs()
                } label: {
                    Label("Face PNGs", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentTeal)
                .disabled(exportVM.isExporting || hasErrors)

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
                .disabled(exportVM.isExporting || hasErrors)
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
                TextField("andy", text: $skinVM.project.name)
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

    // MARK: - Painting Sidebar

    @ViewBuilder
    private var paintingSidebarContent: some View {
        sectionHeader("PAINTING")

        // Painting-Name
        HStack {
            Text("Name:")
                .font(.system(size: 11, weight: .medium))
            TextField("painting_name", text: $paintingVM.project.name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .controlSize(.small)
        }

        // Größen-Auswahl
        sectionHeader("GRÖSSE")

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
            ForEach(PaintingSize.allCases) { size in
                Button {
                    paintingVM.resize(to: size)
                    canvasVM.resetUndoHistory()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: size.iconName)
                            .font(.system(size: 12))
                        Text(size.rawValue)
                            .font(.system(size: 9, weight: .bold))
                        Text(size.description)
                            .font(.system(size: 7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(paintingVM.project.size == size ? accentTeal : nil)
            }
        }

        // Info
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.system(size: 9))
            Text("\(paintingVM.project.size.blocksWide)×\(paintingVM.project.size.blocksTall) Blöcke · \(paintingVM.project.size.pixelWidth)×\(paintingVM.project.size.pixelHeight) px")
                .font(.system(size: 9, design: .monospaced))
        }
        .foregroundStyle(.tertiary)
    }

    // MARK: - Painting Export Card

    private var paintingExportCard: some View {
        VStack(spacing: 10) {
            sectionHeader("EXPORT")

            // Namespace
            HStack {
                Text("Namespace:")
                    .font(.system(size: 10, weight: .medium))
                TextField("custom", text: $paintingVM.project.namespace)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10, design: .monospaced))
                    .controlSize(.small)
            }

            // Transparenter Hintergrund
            Toggle("Transparenter Hintergrund", isOn: $exportVM.transparentBackground)
                .font(.system(size: 11))
                .toggleStyle(.switch)
                .controlSize(.small)

            exportBadge("\(paintingVM.project.size.rawValue)", icon: "photo.artframe", color: .purple)

            // Export-Buttons
            VStack(spacing: 6) {
                Button {
                    exportPaintingPNG()
                } label: {
                    Label("Painting PNG", systemImage: "photo")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentTeal)

                Button {
                    exportVM.exportPaintingDatapack(paintingVM: paintingVM)
                } label: {
                    Label("Datapack (painting_variant)", systemImage: "shippingbox")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentTeal.opacity(0.7))
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

    private func exportPaintingPNG() {
        let canvas = paintingVM.project.canvas
        guard let cgImage = canvas.toCGImage() else { return }

        #if canImport(AppKit)
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = rep.representation(using: .png, properties: [:]) else { return }
        #elseif canImport(UIKit)
        guard let pngData = UIImage(cgImage: cgImage).pngData() else { return }
        #else
        return
        #endif

        let fileName = "\(paintingVM.project.name).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? pngData.write(to: url, options: .atomic)

        exportVM.exportedFileURL = url
        exportVM.showShareSheet = true
    }

    // MARK: - Recipe Sidebar

    @ViewBuilder
    private var recipeSidebarContent: some View {
        sectionHeader("REZEPT")

        // Rezept-Name
        HStack {
            Text("Name:")
                .font(.system(size: 11, weight: .medium))
            TextField("recipe_name", text: $recipeVM.recipe.name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .controlSize(.small)
        }

        // Namespace
        HStack {
            Text("Namespace:")
                .font(.system(size: 10, weight: .medium))
            TextField("minecraft", text: $recipeVM.recipe.namespace)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10, design: .monospaced))
                .controlSize(.small)
        }

        // Info
        HStack(spacing: 4) {
            Image(systemName: recipeVM.recipe.type.iconName)
                .font(.system(size: 9))
            Text(recipeVM.recipe.type.description)
                .font(.system(size: 9, design: .monospaced))
        }
        .foregroundStyle(.tertiary)
    }

    // MARK: - Recipe Export Card

    private var recipeExportCard: some View {
        VStack(spacing: 10) {
            sectionHeader("EXPORT")

            exportBadge(recipeVM.recipe.type.rawValue, icon: recipeVM.recipe.type.iconName, color: .orange)

            VStack(spacing: 6) {
                Button {
                    exportVM.exportRecipeJSON(recipeVM: recipeVM)
                } label: {
                    Label("Recipe JSON", systemImage: "doc.text")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentTeal)

                Button {
                    exportVM.exportDatapack(recipeVM: recipeVM)
                } label: {
                    Label("Datapack", systemImage: "shippingbox")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentTeal.opacity(0.7))
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

    // MARK: - Entity Sidebar

    @ViewBuilder
    private var entitySidebarContent: some View {
        sectionHeader("ENTITY")

        // Entity-Name
        HStack {
            Text("Name:")
                .font(.system(size: 11, weight: .medium))
            TextField("entity_name", text: $entityVM.project.name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .controlSize(.small)
        }

        // Entity-Typ
        sectionHeader("MOB-TYP")

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
            ForEach(EntityType.allCases) { type in
                Button {
                    entityVM.changeEntityType(type)
                    canvasVM.resetUndoHistory()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: type.iconName)
                            .font(.system(size: 12))
                        Text(type.rawValue)
                            .font(.system(size: 8, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(entityVM.project.entityType == type ? accentTeal : nil)
            }
        }

        // Textur-Info
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.system(size: 9))
            Text("\(entityVM.project.entityType.textureWidth)×\(entityVM.project.entityType.textureHeight) px")
                .font(.system(size: 9, design: .monospaced))
        }
        .foregroundStyle(.tertiary)

        Divider()

        // Körperteil-Selector
        sectionHeader("KÖRPERTEIL")

        VStack(spacing: 3) {
            ForEach(Array(entityVM.project.entityType.bodyParts.enumerated()), id: \.element.id) { index, part in
                Button {
                    canvasVM.resetUndoHistory()
                    entityVM.selectPart(index)
                } label: {
                    HStack(spacing: 6) {
                        Text(part.name)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Spacer()
                        Text("\(part.boxW)×\(part.boxH)×\(part.boxD)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(entityVM.activePartIndex == index ? accentTeal.opacity(0.15) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(entityVM.activePartIndex == index ? accentTeal.opacity(0.5) : .white.opacity(0.06), lineWidth: 1)
                    )
                    .foregroundStyle(entityVM.activePartIndex == index ? accentTeal : .secondary)
                }
                .buttonStyle(.plain)
            }
        }

        Divider()

        // Face-Selector
        sectionHeader("FACE")

        HStack(spacing: 4) {
            ForEach(SkinFace.allCases) { face in
                Button {
                    canvasVM.resetUndoHistory()
                    entityVM.selectFace(face)
                } label: {
                    Text(face.shortLabel)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(entityVM.activeFace == face ? accentTeal : nil)
            }
        }

        // Aktuelle Region-Info
        let region = entityVM.activeBodyPart.region(for: entityVM.activeFace)
        Text("UV: (\(region.x),\(region.y)) \(region.width)×\(region.height)")
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(.tertiary)

        Divider()

        // 3D Vorschau
        HStack {
            sectionHeader("3D VORSCHAU")
            Spacer()
            Toggle(isOn: $paint3DEnabled) {
                Image(systemName: "paintbrush")
                    .font(.system(size: 10, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.mini)
            .tint(paint3DEnabled ? accentTeal : nil)
            .help("Direkt auf 3D-Modell malen")
            Toggle(isOn: $show3DGrid) {
                Image(systemName: "grid")
                    .font(.system(size: 10, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.mini)
            .help("Pixel-Grid auf 3D-Modell")
        }

        EntityPreviewView(showGrid: show3DGrid, paintEnabled: paint3DEnabled)
    }

    // MARK: - Entity Export Card

    private var entityExportCard: some View {
        VStack(spacing: 10) {
            sectionHeader("EXPORT")

            // Namespace
            HStack {
                Text("Namespace:")
                    .font(.system(size: 10, weight: .medium))
                TextField("minecraft", text: $entityVM.project.namespace)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10, design: .monospaced))
                    .controlSize(.small)
            }

            // Transparenter Hintergrund
            Toggle("Transparenter Hintergrund", isOn: $exportVM.transparentBackground)
                .font(.system(size: 11))
                .toggleStyle(.switch)
                .controlSize(.small)

            exportBadge(entityVM.project.entityType.rawValue, icon: entityVM.project.entityType.iconName, color: .mint)

            // Export-Buttons
            VStack(spacing: 6) {
                Button {
                    exportEntityPNG()
                } label: {
                    Label("Entity PNG", systemImage: "photo")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentTeal)

                Button {
                    exportVM.exportEntityResourcepack(entityVM: entityVM)
                } label: {
                    Label("Resourcepack", systemImage: "shippingbox")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentTeal.opacity(0.7))
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

    private func exportEntityPNG() {
        let canvas = entityVM.project.texture
        guard let cgImage = canvas.toCGImage() else { return }

        #if canImport(AppKit)
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = rep.representation(using: .png, properties: [:]) else { return }
        #elseif canImport(UIKit)
        guard let pngData = UIImage(cgImage: cgImage).pngData() else { return }
        #else
        return
        #endif

        let fileName = "\(entityVM.project.name).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? pngData.write(to: url, options: .atomic)

        exportVM.exportedFileURL = url
        exportVM.showShareSheet = true
    }

    // MARK: - Armor Sidebar

    @ViewBuilder
    private var armorSidebarContent: some View {
        sectionHeader("RÜSTUNG")

        // Armor-Name
        HStack {
            Text("Name:")
                .font(.system(size: 11, weight: .medium))
            TextField("armor_name", text: $armorVM.project.name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .controlSize(.small)
        }

        // Material-Selector
        sectionHeader("MATERIAL")

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
            ForEach(ArmorMaterial.allCases) { material in
                Button {
                    armorVM.project.material = material
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: material.iconName)
                            .font(.system(size: 12))
                        Text(material.rawValue)
                            .font(.system(size: 8, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(armorVM.project.material == material ? accentTeal : nil)
            }
        }

        Divider()

        // Layer-Anzeige
        HStack(spacing: 8) {
            ForEach(ArmorLayer.allCases) { layer in
                VStack(spacing: 2) {
                    Image(systemName: layer.iconName)
                        .font(.system(size: 11))
                    Text(layer.rawValue)
                        .font(.system(size: 8, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(armorVM.activeLayer == layer ? accentTeal.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(armorVM.activeLayer == layer ? accentTeal.opacity(0.4) : .white.opacity(0.06), lineWidth: 1)
                )
                .foregroundStyle(armorVM.activeLayer == layer ? accentTeal : .secondary)
            }
        }

        Text(armorVM.activeLayer.description)
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(.tertiary)

        Divider()

        // Rüstungsteil-Selector
        sectionHeader("RÜSTUNGSTEIL")

        VStack(spacing: 3) {
            ForEach(ArmorPiece.allCases) { piece in
                Button {
                    canvasVM.resetUndoHistory()
                    armorVM.selectPiece(piece)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: piece.iconName)
                            .font(.system(size: 9))
                        Text(piece.rawValue)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Spacer()
                        Text(piece.armorLayer.rawValue)
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(armorVM.activePiece == piece ? accentTeal.opacity(0.15) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(armorVM.activePiece == piece ? accentTeal.opacity(0.5) : .white.opacity(0.06), lineWidth: 1)
                    )
                    .foregroundStyle(armorVM.activePiece == piece ? accentTeal : .secondary)
                }
                .buttonStyle(.plain)
            }
        }

        Divider()

        // Face-Selector
        sectionHeader("FACE")

        HStack(spacing: 4) {
            ForEach(SkinFace.allCases) { face in
                Button {
                    canvasVM.resetUndoHistory()
                    armorVM.selectFace(face)
                } label: {
                    Text(face.shortLabel)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(armorVM.activeFace == face ? accentTeal : nil)
            }
        }

        // Aktuelle Region-Info
        let region = ArmorUVMap.region(piece: armorVM.activePiece, face: armorVM.activeFace)
        Text("UV: (\(region.x),\(region.y)) \(region.width)×\(region.height)")
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(.tertiary)
    }

    // MARK: - Armor Export Card

    private var armorExportCard: some View {
        VStack(spacing: 10) {
            sectionHeader("EXPORT")

            // Namespace
            HStack {
                Text("Namespace:")
                    .font(.system(size: 10, weight: .medium))
                TextField("minecraft", text: $armorVM.project.namespace)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10, design: .monospaced))
                    .controlSize(.small)
            }

            // Transparenter Hintergrund
            Toggle("Transparenter Hintergrund", isOn: $exportVM.transparentBackground)
                .font(.system(size: 11))
                .toggleStyle(.switch)
                .controlSize(.small)

            exportBadge(armorVM.project.material.rawValue, icon: armorVM.project.material.iconName, color: .yellow)

            // Info
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 9))
                Text("Layer 1 + Layer 2 (je 64×32)")
                    .font(.system(size: 9, design: .monospaced))
            }
            .foregroundStyle(.tertiary)

            // Export-Buttons
            VStack(spacing: 6) {
                Button {
                    exportArmorPNGs()
                } label: {
                    Label("Armor PNGs", systemImage: "photo.on.rectangle")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentTeal)

                Button {
                    exportVM.exportArmorResourcepack(armorVM: armorVM)
                } label: {
                    Label("Resourcepack", systemImage: "shippingbox")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentTeal.opacity(0.7))
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

    private func exportArmorPNGs() {
        var urls: [URL] = []

        // Layer 1
        let layer1 = armorVM.project.layer1
        if let cgImage1 = layer1.toCGImage() {
            #if canImport(AppKit)
            let rep1 = NSBitmapImageRep(cgImage: cgImage1)
            if let pngData = rep1.representation(using: .png, properties: [:]) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(armorVM.project.name)_layer_1.png")
                try? pngData.write(to: url, options: .atomic)
                urls.append(url)
            }
            #elseif canImport(UIKit)
            if let pngData = UIImage(cgImage: cgImage1).pngData() {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(armorVM.project.name)_layer_1.png")
                try? pngData.write(to: url, options: .atomic)
                urls.append(url)
            }
            #endif
        }

        // Layer 2
        let layer2 = armorVM.project.layer2
        if let cgImage2 = layer2.toCGImage() {
            #if canImport(AppKit)
            let rep2 = NSBitmapImageRep(cgImage: cgImage2)
            if let pngData = rep2.representation(using: .png, properties: [:]) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(armorVM.project.name)_layer_2.png")
                try? pngData.write(to: url, options: .atomic)
                urls.append(url)
            }
            #elseif canImport(UIKit)
            if let pngData = UIImage(cgImage: cgImage2).pngData() {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(armorVM.project.name)_layer_2.png")
                try? pngData.write(to: url, options: .atomic)
                urls.append(url)
            }
            #endif
        }

        if let first = urls.first {
            exportVM.exportedFileURL = first
            exportVM.additionalExportURLs = Array(urls.dropFirst())
            exportVM.showShareSheet = true
        }
    }

    // MARK: - Resourcepack Section (Multi-Asset)

    @ViewBuilder
    private var resourcepackSection: some View {
        sectionHeader("RESOURCEPACK")

        // Pack-Name
        HStack {
            Text("Pack:")
                .font(.system(size: 10, weight: .medium))
            TextField("my_resourcepack", text: $resourcepackVM.project.name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10, design: .monospaced))
                .controlSize(.small)
        }

        // Namespace
        HStack {
            Text("Namespace:")
                .font(.system(size: 10, weight: .medium))
            TextField("custom", text: $resourcepackVM.project.namespace)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10, design: .monospaced))
                .controlSize(.small)
        }

        // Asset-Liste
        VStack(spacing: 4) {
            // Blöcke
            ForEach(0..<resourcepackVM.project.blocks.count, id: \.self) { i in
                assetRow(icon: "cube", name: resourcepackVM.project.blocks[i].name, color: .cyan) {
                    resourcepackVM.removeBlock(at: i)
                }
            }
            // Items
            ForEach(0..<resourcepackVM.project.items.count, id: \.self) { i in
                assetRow(icon: "shield", name: resourcepackVM.project.items[i].name, color: .green) {
                    resourcepackVM.removeItem(at: i)
                }
            }
            // Paintings
            ForEach(0..<resourcepackVM.project.paintings.count, id: \.self) { i in
                assetRow(icon: "photo.artframe", name: resourcepackVM.project.paintings[i].name, color: .purple) {
                    resourcepackVM.removePainting(at: i)
                }
            }
            // Recipes
            ForEach(0..<resourcepackVM.project.recipes.count, id: \.self) { i in
                assetRow(icon: "square.grid.3x3", name: resourcepackVM.project.recipes[i].name, color: .orange) {
                    resourcepackVM.removeRecipe(at: i)
                }
            }
            // Entities
            ForEach(0..<resourcepackVM.project.entities.count, id: \.self) { i in
                assetRow(icon: "hare", name: resourcepackVM.project.entities[i].name, color: .mint) {
                    resourcepackVM.removeEntity(at: i)
                }
            }
            // Armors
            ForEach(0..<resourcepackVM.project.armors.count, id: \.self) { i in
                assetRow(icon: "shield.lefthalf.filled", name: resourcepackVM.project.armors[i].name, color: .yellow) {
                    resourcepackVM.removeArmor(at: i)
                }
            }
        }

        if resourcepackVM.project.totalAssetCount == 0 {
            Text("Noch keine Assets. Nutze '+' um\naktuellen Editor-Inhalt hinzuzufügen.")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }

        // Hinzufügen-Buttons
        HStack(spacing: 4) {
            Button {
                resourcepackVM.importCurrentBlock(from: blockVM)
            } label: {
                Label("Block", systemImage: "plus")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tint(.cyan)

            Button {
                resourcepackVM.importCurrentItem(from: itemVM)
            } label: {
                Label("Item", systemImage: "plus")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tint(.green)

            Button {
                resourcepackVM.importCurrentPainting(from: paintingVM)
            } label: {
                Label("Painting", systemImage: "plus")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tint(.purple)

            if canvasVM.editorMode == .recipe {
                Button {
                    resourcepackVM.importCurrentRecipe(from: recipeVM)
                } label: {
                    Label("Rezept", systemImage: "plus")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.orange)
            }
        }

        HStack(spacing: 4) {
            if canvasVM.editorMode == .entity {
                Button {
                    resourcepackVM.importCurrentEntity(from: entityVM)
                } label: {
                    Label("Entity", systemImage: "plus")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.mint)
            }

            if canvasVM.editorMode == .armor {
                Button {
                    resourcepackVM.importCurrentArmor(from: armorVM)
                } label: {
                    Label("Armor", systemImage: "plus")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.yellow)
            }
        }

        // Export Resourcepack + Datapack
        if resourcepackVM.project.totalAssetCount > 0 {
            VStack(spacing: 6) {
                Button {
                    exportVM.exportCombinedResourcepack(resourcepackVM: resourcepackVM)
                } label: {
                    Label("Resourcepack exportieren (\(resourcepackVM.project.totalAssetCount) Assets)", systemImage: "shippingbox.fill")
                        .font(.system(size: 10, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentTeal)

                if !resourcepackVM.project.recipes.isEmpty {
                    Button {
                        exportVM.exportCombinedDatapack(resourcepackVM: resourcepackVM)
                    } label: {
                        Label("Datapack exportieren (\(resourcepackVM.project.recipes.count) Recipes)", systemImage: "doc.text.fill")
                            .font(.system(size: 10, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.orange)
                }
            }
        }
    }

    private func assetRow(icon: String, name: String, color: Color, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text(name)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            Spacer()
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red.opacity(0.5))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.08))
        )
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
