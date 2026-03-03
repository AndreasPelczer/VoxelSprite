//
//  ToolBarView.swift
//  PlanktonSpriteApp
//
//  Created by Andreas Pelczer on 27.02.26.
//


import SwiftUI

/// Die Werkzeugleiste über dem Canvas.
/// Stift, Radierer, Füllen, Grid-Toggle, Undo/Redo, Leeren.
struct ToolBarView: View {
    
    @EnvironmentObject var canvasVM: CanvasViewModel
    
    var body: some View {
        HStack(spacing: 6) {

            // MARK: - Werkzeuge

            ForEach(CanvasViewModel.Tool.allCases, id: \.self) { tool in
                toolButton(tool)
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
                .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 0.85).opacity(0.8))
                .frame(width: 36)

            actionButton(icon: "plus.magnifyingglass", label: "Zoom +", enabled: canvasVM.zoomScale < canvasVM.maxZoom) {
                canvasVM.zoomIn()
            }

            divider

            // MARK: - Onion Skin Toggle

            Toggle(isOn: $canvasVM.onionSkinEnabled) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 12, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .help("Onion Skin")

            divider

            // MARK: - Canvas leeren

            actionButton(
                icon: "trash",
                label: "Frame leeren",
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
    }
    
    // MARK: - Subviews
    
    /// Button für ein Werkzeug (Stift, Radierer, Füllen, Linie, Rechteck)
    private func toolButton(_ tool: CanvasViewModel.Tool) -> some View {
        let isActive = canvasVM.currentTool == tool
        let teal = Color(red: 0.0, green: 0.85, blue: 0.85)

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
    
    /// Button für eine Aktion (Undo, Redo, Leeren)
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
    
    /// Optischer Trenner zwischen Gruppen
    private var divider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 18)
    }
    
    /// Ordnet jedem Tool eine Taste zu.
    /// KeyEquivalent akzeptiert nur Character –
    /// deshalb der Umweg über die Zahl.
    private func shortcutKey(for tool: CanvasViewModel.Tool) -> KeyEquivalent {
        switch tool {
        case .pen:       return "1"
        case .eraser:    return "2"
        case .fill:      return "3"
        case .line:      return "4"
        case .rectangle: return "5"
        }
    }
}
