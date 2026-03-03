//
//  AnimationTimelineView.swift
//  VoxelSprite
//
//  Timeline-Leiste für Animations-Frames.
//  Zeigt Frame-Thumbnails in einer horizontalen ScrollView.
//  Unterstützt: Frame hinzufügen, duplizieren, löschen, umordnen.
//  Labels passen sich dem CTM-Modus an (Frames vs. Tiles vs. Varianten).
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct AnimationTimelineView: View {

    @EnvironmentObject var blockVM: BlockViewModel
    @EnvironmentObject var canvasVM: CanvasViewModel

    private let teal = Color(red: 0.0, green: 0.85, blue: 0.85)
    private let thumbSize: CGFloat = 48

    /// Label je nach CTM-Modus
    private var itemLabel: String {
        switch blockVM.project.ctmMethod {
        case .none:    return "Frame"
        case .random:  return "Variante"
        case .repeat_: return "Tile"
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Header mit Info
            HStack(spacing: 6) {
                Image(systemName: headerIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(teal)

                Text(headerTitle)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(blockVM.activeFrameIndex + 1)/\(blockVM.activeFrameCount)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(teal)

                // Controls
                controlButtons
            }

            // Frame-Thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(0..<blockVM.activeFace.frames.count, id: \.self) { index in
                        frameThumb(index)
                    }

                    // Add-Button am Ende
                    addButton
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var headerIcon: String {
        switch blockVM.project.ctmMethod {
        case .none:    return "film"
        case .random:  return "dice"
        case .repeat_: return "square.grid.2x2"
        }
    }

    private var headerTitle: String {
        switch blockVM.project.ctmMethod {
        case .none:    return "FRAMES"
        case .random:  return "VARIANTEN"
        case .repeat_: return "TILES"
        }
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: 2) {
            // Duplizieren
            Button {
                canvasVM.resetUndoHistory()
                blockVM.duplicateFrame()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("\(itemLabel) duplizieren")

            // Löschen
            if blockVM.activeFrameCount > 1 {
                Button {
                    canvasVM.resetUndoHistory()
                    blockVM.deleteFrame()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.7))
                .help("\(itemLabel) löschen")
            }

            // Links verschieben
            if blockVM.activeFrameIndex > 0 {
                Button {
                    blockVM.moveFrameLeft()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            // Rechts verschieben
            if blockVM.activeFrameIndex < blockVM.activeFrameCount - 1 {
                Button {
                    blockVM.moveFrameRight()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Frame Thumbnail

    private func frameThumb(_ index: Int) -> some View {
        let isActive = index == blockVM.activeFrameIndex
        let canvas = blockVM.activeFace.frames[index]

        return Button {
            canvasVM.resetUndoHistory()
            blockVM.selectFrame(index)
        } label: {
            VStack(spacing: 2) {
                // Mini-Canvas Vorschau
                if let cgImage = canvas.toCGImage() {
                    #if os(macOS)
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: canvas.width, height: canvas.height))
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: thumbSize, height: thumbSize)
                    #elseif os(iOS)
                    Image(uiImage: UIImage(cgImage: cgImage))
                        .resizable()
                        .interpolation(.none)
                        .frame(width: thumbSize, height: thumbSize)
                    #endif
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: thumbSize, height: thumbSize)
                }

                // Frame-Nummer
                Text("\(index + 1)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(isActive ? teal : .secondary)
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? teal.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? teal.opacity(0.6) : .white.opacity(0.08), lineWidth: isActive ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            canvasVM.resetUndoHistory()
            blockVM.addFrame()
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .frame(width: thumbSize, height: thumbSize)

                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text("+")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(3)
        }
        .buttonStyle(.plain)
        .help("Neuen \(itemLabel) hinzufügen")
    }
}
