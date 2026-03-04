//
//  BodyPartSelectorView.swift
//  VoxelSprite
//
//  Auswahl von Körperteil, Face und Layer für den Andy-Skin-Editor.
//  Zeigt Thumbnails der Körperteil-Faces als klickbare Buttons.
//

import SwiftUI

struct BodyPartSelectorView: View {

    @EnvironmentObject var skinVM: SkinViewModel
    @EnvironmentObject var canvasVM: CanvasViewModel

    private let teal = Color(red: 0.0, green: 0.85, blue: 0.85)

    var body: some View {
        VStack(spacing: 8) {

            // MARK: - Körperteil-Auswahl

            HStack {
                Text("KÖRPERTEIL")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(skinVM.activeBodyPart.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(teal)
            }

            // Körperteil-Grid: 2×3
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
            ], spacing: 4) {
                ForEach(SkinBodyPart.allCases) { part in
                    bodyPartButton(part)
                }
            }

            Divider()

            // MARK: - Face-Auswahl

            HStack {
                Text("FACE")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(skinVM.activeFace.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(teal)
            }

            // Face-Buttons: Kreuzform
            faceCrossLayout

            Divider()

            // MARK: - Layer-Auswahl

            HStack {
                Text("LAYER")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(SkinLayer.allCases) { layer in
                    layerButton(layer)
                }
            }

            // Dimensionen-Info
            let region = SkinUVMap.region(bodyPart: skinVM.activeBodyPart, face: skinVM.activeFace, layer: skinVM.activeLayer)
            HStack {
                Spacer()
                Text("\(region.width) × \(region.height) px")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 2)
                Spacer()
            }
        }
    }

    // MARK: - Körperteil-Button

    private func bodyPartButton(_ part: SkinBodyPart) -> some View {
        let isActive = part == skinVM.activeBodyPart

        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                canvasVM.resetUndoHistory()
                skinVM.selectBodyPart(part)
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: part.iconName)
                    .font(.system(size: 16, weight: isActive ? .bold : .medium))
                Text(part.rawValue)
                    .font(.system(size: 9, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? teal.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? teal.opacity(0.5) : .white.opacity(0.1), lineWidth: isActive ? 1.5 : 0.5)
            )
            .foregroundStyle(isActive ? teal : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Face Kreuzform

    ///        [Top]
    /// [Left][Front][Right][Back]
    ///        [Bottom]
    private var faceCrossLayout: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Spacer().frame(width: faceButtonWidth + 2)
                faceButton(.top)
                Spacer().frame(width: (faceButtonWidth + 2) * 2)
            }

            HStack(spacing: 2) {
                faceButton(.left)
                faceButton(.front)
                faceButton(.right)
                faceButton(.back)
            }

            HStack(spacing: 2) {
                Spacer().frame(width: faceButtonWidth + 2)
                faceButton(.bottom)
                Spacer().frame(width: (faceButtonWidth + 2) * 2)
            }
        }
    }

    private var faceButtonWidth: CGFloat { 52 }

    private func faceButton(_ face: SkinFace) -> some View {
        let isActive = face == skinVM.activeFace

        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                canvasVM.resetUndoHistory()
                skinVM.selectFace(face)
            }
        } label: {
            Text(face.shortLabel)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(width: faceButtonWidth, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? teal.opacity(0.2) : Color(red: 0.12, green: 0.12, blue: 0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isActive ? teal : .white.opacity(0.1), lineWidth: isActive ? 1.5 : 0.5)
                )
                .foregroundStyle(isActive ? teal : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Layer-Button

    private func layerButton(_ layer: SkinLayer) -> some View {
        let isActive = layer == skinVM.activeLayer

        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                canvasVM.resetUndoHistory()
                skinVM.selectLayer(layer)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: layer.iconName)
                    .font(.system(size: 12))
                Text(layer.rawValue)
                    .font(.system(size: 11, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? teal.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? teal.opacity(0.5) : .white.opacity(0.1), lineWidth: isActive ? 1.5 : 0.5)
            )
            .foregroundStyle(isActive ? teal : .secondary)
        }
        .buttonStyle(.plain)
    }
}
