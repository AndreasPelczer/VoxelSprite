//
//  ToolBarView.swift
//  VoxelSprite
//
//  Die Werkzeugleiste über dem Canvas.
//  Stift, Radierer, Füllen, Linie, Rechteck, Pipette,
//  Transformationen, Grid-Toggle, Undo/Redo, Import.
//

import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct ToolBarView: View {

    @EnvironmentObject var canvasVM: CanvasViewModel

    @State private var showImportPicker = false
    @State private var showPaletteReduce = false
    @State private var paletteReduceDithering = false

    /// Electric Teal Akzentfarbe
    private let teal = Color(red: 0.0, green: 0.85, blue: 0.85)

    var body: some View {
        HStack(spacing: 6) {

            // MARK: - Werkzeuge

            ForEach(CanvasViewModel.Tool.allCases, id: \.self) { tool in
                toolButton(tool)
            }

            divider

            // MARK: - Transformationen

            actionButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", label: "Horizontal spiegeln", enabled: canvasVM.editorMode != .recipe) {
                canvasVM.mirrorHorizontal()
            }

            actionButton(icon: "arrow.up.and.down.righttriangle.up.righttriangle.down", label: "Vertikal spiegeln", enabled: canvasVM.editorMode != .recipe) {
                canvasVM.mirrorVertical()
            }

            actionButton(icon: "rotate.right", label: "90° drehen", enabled: canvasVM.editorMode != .recipe && canvasVM.canvasWidth == canvasVM.canvasHeight) {
                canvasVM.rotateCW()
            }

            divider

            // MARK: - Undo / Redo

            actionButton(
                icon: "arrow.uturn.backward",
                label: "Rückgängig",
                enabled: canvasVM.canUndo
            ) {
                canvasVM.undo()
            }

            actionButton(
                icon: "arrow.uturn.forward",
                label: "Wiederherstellen",
                enabled: canvasVM.canRedo
            ) {
                canvasVM.redo()
            }

            divider

            // MARK: - Grid Toggle

            Toggle(isOn: $canvasVM.showGrid) {
                Image(systemName: "grid")
                    .font(.system(size: 12, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .help("Rasterlinien ein/aus")

            divider

            // MARK: - Zoom

            actionButton(icon: "minus.magnifyingglass", label: "Zoom -", enabled: canvasVM.zoomScale > canvasVM.minZoom) {
                canvasVM.zoomOut()
            }

            Text("\(Int(canvasVM.zoomScale * 100))%")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(teal.opacity(0.8))
                .frame(width: 36)

            actionButton(icon: "plus.magnifyingglass", label: "Zoom +", enabled: canvasVM.zoomScale < canvasVM.maxZoom) {
                canvasVM.zoomIn()
            }

            divider

            // MARK: - Face Overlay Toggle

            Toggle(isOn: $canvasVM.faceOverlayEnabled) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 12, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .help("Face Overlay")

            // MARK: - Wrap Painting (Tile-Modus)

            Toggle(isOn: $canvasVM.wrapPaintingEnabled) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 12, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .help("Wrap Painting (nahtlos)")

            // MARK: - Tile Check

            actionButton(
                icon: tileCheckIcon,
                label: "Tile-Check",
                enabled: canvasVM.editorMode == .block
            ) {
                canvasVM.runTileCheck()
            }

            // Toleranz-Toggle (exact vs tolerant)
            Toggle(isOn: $canvasVM.tileCheckTolerant) {
                Text("≈")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .help("Toleranter Vergleich (ΔRGBA ≤ 2%)")

            // MARK: - Palette Reduce

            Button {
                showPaletteReduce.toggle()
            } label: {
                Image(systemName: "paintpalette")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .disabled(canvasVM.editorMode == .recipe)
            .help("Palette Reduce")
            .popover(isPresented: $showPaletteReduce) {
                paletteReducePopover
            }

            divider

            // MARK: - Import PNG

            actionButton(
                icon: "square.and.arrow.down.on.square",
                label: "PNG importieren",
                enabled: canvasVM.editorMode != .recipe
            ) {
                showImportPicker = true
            }

            divider

            // MARK: - Canvas leeren

            actionButton(
                icon: "trash",
                label: "Face leeren",
                enabled: true,
                destructive: true
            ) {
                canvasVM.clearCanvas()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.png, .jpeg, .tiff, .bmp],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    private var tileCheckIcon: String {
        if let result = canvasVM.tileCheckResult {
            return result.isSeamless ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
        }
        return "checkmark.seal"
    }

    // MARK: - Import Handler

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return }

        #if canImport(AppKit)
        guard let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        canvasVM.importImage(cgImage)
        #elseif canImport(UIKit)
        guard let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else { return }
        canvasVM.importImage(cgImage)
        #endif
    }

    // MARK: - Subviews

    private func toolButton(_ tool: CanvasViewModel.Tool) -> some View {
        let isActive = canvasVM.currentTool == tool

        return Button {
            withAnimation(.easeOut(duration: 0.12)) {
                canvasVM.currentTool = tool
            }
        } label: {
            Image(systemName: tool.iconName)
                .font(.system(size: 13, weight: isActive ? .bold : .medium))
                .foregroundStyle(isActive ? teal : .primary)
                .frame(width: 32, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? teal.opacity(0.2) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? teal.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(tool.rawValue)
        .keyboardShortcut(shortcutKey(for: tool), modifiers: [])
    }

    private func actionButton(
        icon: String,
        label: String,
        enabled: Bool,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle({
                    if !enabled {
                        return AnyShapeStyle(.tertiary)
                    } else if destructive {
                        return AnyShapeStyle(Color.red)
                    } else {
                        return AnyShapeStyle(.primary)
                    }
                }())
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(label)
    }

    private var divider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 18)
    }

    // MARK: - Palette Reduce Popover

    private var paletteReducePopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Palette Reduce")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(teal)

            Toggle("Floyd-Steinberg Dithering", isOn: $paletteReduceDithering)
                .font(.system(size: 10))
                .controlSize(.small)

            Divider()

            Text("Rückgängig mit ⌘Z")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            ForEach(PresetPalette.allCases, id: \.self) { preset in
                Button {
                    canvasVM.reduceToPalette(preset.colors, dithering: paletteReduceDithering)
                    showPaletteReduce = false
                } label: {
                    HStack(spacing: 4) {
                        Text(preset.label)
                            .font(.system(size: 10, weight: .medium))
                        Spacer()
                        // Color swatches
                        ForEach(Array(preset.colors.prefix(8).enumerated()), id: \.offset) { _, color in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(width: 10, height: 10)
                        }
                        if preset.colors.count > 8 {
                            Text("+\(preset.colors.count - 8)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 280)
    }

    /// Vordefinierte Minecraft-Paletten
    private enum PresetPalette: CaseIterable {
        case stone
        case wood
        case nether
        case ocean
        case grayscale4
        case grayscale8

        var label: String {
            switch self {
            case .stone:      return "Stone (6 Farben)"
            case .wood:       return "Wood (6 Farben)"
            case .nether:     return "Nether (6 Farben)"
            case .ocean:      return "Ocean (6 Farben)"
            case .grayscale4: return "Graustufen (4)"
            case .grayscale8: return "Graustufen (8)"
            }
        }

        var colors: [Color] {
            switch self {
            case .stone:
                return [
                    Color(red: 0.50, green: 0.50, blue: 0.50), // Stone Gray
                    Color(red: 0.65, green: 0.65, blue: 0.65), // Light Stone
                    Color(red: 0.35, green: 0.35, blue: 0.35), // Dark Stone
                    Color(red: 0.55, green: 0.53, blue: 0.48), // Andesite
                    Color(red: 0.72, green: 0.70, blue: 0.65), // Diorite
                    Color(red: 0.25, green: 0.25, blue: 0.25), // Deepslate
                ]
            case .wood:
                return [
                    Color(red: 0.65, green: 0.45, blue: 0.25), // Oak
                    Color(red: 0.40, green: 0.25, blue: 0.12), // Dark Oak
                    Color(red: 0.75, green: 0.60, blue: 0.35), // Birch
                    Color(red: 0.55, green: 0.35, blue: 0.18), // Spruce
                    Color(red: 0.82, green: 0.52, blue: 0.25), // Acacia
                    Color(red: 0.50, green: 0.20, blue: 0.22), // Mangrove
                ]
            case .nether:
                return [
                    Color(red: 0.55, green: 0.10, blue: 0.10), // Netherrack
                    Color(red: 0.85, green: 0.50, blue: 0.10), // Magma
                    Color(red: 0.20, green: 0.05, blue: 0.05), // Blackstone
                    Color(red: 0.40, green: 0.35, blue: 0.30), // Basalt
                    Color(red: 0.95, green: 0.85, blue: 0.55), // Glowstone
                    Color(red: 0.10, green: 0.50, blue: 0.50), // Warped
                ]
            case .ocean:
                return [
                    Color(red: 0.10, green: 0.30, blue: 0.60), // Deep Water
                    Color(red: 0.20, green: 0.50, blue: 0.75), // Water
                    Color(red: 0.30, green: 0.65, blue: 0.65), // Prismarine
                    Color(red: 0.85, green: 0.85, blue: 0.70), // Sand
                    Color(red: 0.50, green: 0.70, blue: 0.40), // Seagrass
                    Color(red: 0.15, green: 0.20, blue: 0.35), // Deep Dark
                ]
            case .grayscale4:
                return [
                    Color(red: 0.0, green: 0.0, blue: 0.0),
                    Color(red: 0.33, green: 0.33, blue: 0.33),
                    Color(red: 0.66, green: 0.66, blue: 0.66),
                    Color(red: 1.0, green: 1.0, blue: 1.0),
                ]
            case .grayscale8:
                return (0..<8).map { i in
                    let v = Double(i) / 7.0
                    return Color(red: v, green: v, blue: v)
                }
            }
        }
    }

    private func shortcutKey(for tool: CanvasViewModel.Tool) -> KeyEquivalent {
        switch tool {
        case .pen:        return "1"
        case .eraser:     return "2"
        case .fill:       return "3"
        case .line:       return "4"
        case .rectangle:  return "5"
        case .eyedropper: return "6"
        }
    }
}
