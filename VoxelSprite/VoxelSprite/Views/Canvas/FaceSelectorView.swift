//
//  FaceSelectorView.swift
//  VoxelSprite
//
//  Der Face-Selector ersetzt die Frame-Leiste aus PlanktonSprite.
//  Zeigt alle 6 Faces als aufgeklappten Würfel (Kreuzform)
//  oder als kompakte Tab-Leiste.
//

import SwiftUI

struct FaceSelectorView: View {

    @EnvironmentObject var blockVM: BlockViewModel
    @EnvironmentObject var canvasVM: CanvasViewModel

    /// Electric Teal
    private let teal = Color(red: 0.0, green: 0.85, blue: 0.85)

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("FACES")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(blockVM.activeFaceType.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(teal)
            }

            // MARK: - Kreuzform-Layout (aufgeklappter Würfel)
            crossLayout
        }
        .padding(.vertical, 4)
    }

    // MARK: - Kreuzform: Aufgeklappter Würfel

    /// Layout:
    ///        [Top]
    ///  [West][North][East][South]
    ///        [Bottom]
    private var crossLayout: some View {
        VStack(spacing: 2) {
            // Obere Reihe: nur Top
            HStack(spacing: 2) {
                Spacer().frame(width: faceSize + 2)
                faceThumb(.top)
                Spacer().frame(width: (faceSize + 2) * 2)
            }

            // Mittlere Reihe: West, North, East, South
            HStack(spacing: 2) {
                faceThumb(.west)
                faceThumb(.north)
                faceThumb(.east)
                faceThumb(.south)
            }

            // Untere Reihe: nur Bottom
            HStack(spacing: 2) {
                Spacer().frame(width: faceSize + 2)
                faceThumb(.bottom)
                Spacer().frame(width: (faceSize + 2) * 2)
            }
        }
    }

    private var faceSize: CGFloat { 48 }

    // MARK: - Einzelnes Face-Thumbnail

    private func faceThumb(_ faceType: FaceType) -> some View {
        let isActive = faceType == blockVM.activeFaceType
        let canvas = blockVM.project.canvas(for: faceType)
        let gs = blockVM.project.gridSize

        return VStack(spacing: 2) {
            // Mini-Canvas
            Canvas { context, size in
                let cellSize = size.width / CGFloat(gs)

                // Hintergrund
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(red: 0.12, green: 0.12, blue: 0.16))
                )

                // Pixel
                for y in 0..<gs {
                    for x in 0..<gs {
                        if let color = canvas.pixel(at: x, y: y) {
                            let rect = CGRect(
                                x: CGFloat(x) * cellSize,
                                y: CGFloat(y) * cellSize,
                                width: cellSize,
                                height: cellSize
                            )
                            context.fill(Path(rect), with: .color(color))
                        }
                    }
                }
            }
            .frame(width: faceSize, height: faceSize)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isActive ? teal : .white.opacity(0.1), lineWidth: isActive ? 2 : 0.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(teal.opacity(isActive ? 0.15 : 0))
                    .blur(radius: 4)
            )
            .shadow(color: isActive ? teal.opacity(0.4) : .clear, radius: 6, y: 0)

            // Label
            Text(faceType.shortLabel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(isActive ? teal : .secondary)
        }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.15)) {
                canvasVM.resetUndoHistory()
                blockVM.selectFace(faceType)
            }
            #if canImport(UIKit)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
        }
    }
}
