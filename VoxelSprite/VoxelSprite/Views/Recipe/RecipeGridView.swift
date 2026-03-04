//
//  RecipeGridView.swift
//  VoxelSprite
//
//  Visueller 3×3 Crafting Grid Editor.
//  Erlaubt das Platzieren von Items per Tap.
//  Zeigt Ergebnis-Slot und Recipe-JSON-Vorschau.
//

import SwiftUI

struct RecipeGridView: View {

    @EnvironmentObject var recipeVM: RecipeViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Rezept-Typ
            recipeTypeSelector

            Divider()

            // Grid oder Single-Input
            if recipeVM.recipe.type.usesGrid || recipeVM.recipe.type == .shapeless {
                craftingGrid
            }

            if recipeVM.recipe.type.usesSingleInput {
                singleInputView
            }

            // Ergebnis
            resultSection

            Divider()

            // Item-Auswahl
            itemSelector

            // JSON-Vorschau
            jsonPreview
        }
    }

    // MARK: - Rezept-Typ Selector

    private var recipeTypeSelector: some View {
        VStack(spacing: 6) {
            HStack {
                Text("REZEPT-TYP")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(RecipeType.allCases) { type in
                        Button {
                            recipeVM.recipe.type = type
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: type.iconName)
                                    .font(.system(size: 12))
                                Text(type.rawValue)
                                    .font(.system(size: 8, weight: .medium))
                                    .lineLimit(1)
                            }
                            .frame(width: 52)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(recipeVM.recipe.type == type ? accentTeal : nil)
                    }
                }
            }
        }
    }

    // MARK: - 3×3 Crafting Grid

    private var craftingGrid: some View {
        VStack(spacing: 8) {
            HStack {
                Text("CRAFTING GRID")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()

                Button {
                    recipeVM.clearGrid()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.6))
            }

            // 3×3 Grid
            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { col in
                            let index = row * 3 + col
                            gridSlotView(index: index, slot: recipeVM.recipe.grid[index])
                        }
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.55, green: 0.55, blue: 0.55).opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - Single Input (Smelting)

    private var singleInputView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ZUTAT")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
            }

            gridSlotView(index: 0, slot: recipeVM.recipe.grid[0])
                .frame(width: 56, height: 56)

            // Cooking-Zeit
            HStack {
                Text("Koch-Zeit:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(value: $recipeVM.recipe.cookingTime, in: 1...6000, step: 20) {
                    Text("\(recipeVM.recipe.cookingTime) Ticks")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentTeal)
                }
                .controlSize(.mini)
            }

            // XP
            HStack {
                Text("XP:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f", recipeVM.recipe.experience))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentTeal)
                Stepper("", value: $recipeVM.recipe.experience, in: 0...10, step: 0.1)
                    .labelsHidden()
                    .controlSize(.mini)
            }
        }
    }

    // MARK: - Grid Slot View

    private func gridSlotView(index: Int, slot: RecipeSlot) -> some View {
        Button {
            if slot.isEmpty {
                recipeVM.placeItem(at: index)
            } else {
                recipeVM.clearSlot(at: index)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(slot.isEmpty ? Color.black.opacity(0.3) : slot.color.opacity(0.3))
                    .frame(width: 48, height: 48)

                RoundedRectangle(cornerRadius: 4)
                    .stroke(slot.isEmpty ? .white.opacity(0.15) : slot.color.opacity(0.6), lineWidth: 1)
                    .frame(width: 48, height: 48)

                if !slot.isEmpty {
                    VStack(spacing: 2) {
                        Circle()
                            .fill(slot.color)
                            .frame(width: 16, height: 16)
                        Text(slot.displayName)
                            .font(.system(size: 6, weight: .bold))
                            .lineLimit(1)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ergebnis

    private var resultSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ERGEBNIS")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
            }

            HStack(spacing: 12) {
                // Ergebnis-Slot
                Button {
                    if recipeVM.recipe.result.isEmpty {
                        recipeVM.setResult()
                    } else {
                        recipeVM.clearResult()
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(recipeVM.recipe.result.isEmpty
                                  ? Color.black.opacity(0.3)
                                  : recipeVM.recipe.result.color.opacity(0.3))
                            .frame(width: 56, height: 56)

                        RoundedRectangle(cornerRadius: 6)
                            .stroke(recipeVM.recipe.result.isEmpty
                                    ? .white.opacity(0.15)
                                    : accentTeal.opacity(0.6), lineWidth: 2)
                            .frame(width: 56, height: 56)

                        if !recipeVM.recipe.result.isEmpty {
                            VStack(spacing: 2) {
                                Circle()
                                    .fill(recipeVM.recipe.result.color)
                                    .frame(width: 20, height: 20)
                                Text(recipeVM.recipe.result.displayName)
                                    .font(.system(size: 7, weight: .bold))
                                    .lineLimit(1)
                                    .foregroundStyle(.white)
                            }
                        } else {
                            Text("Tap")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Anzahl
                VStack(spacing: 4) {
                    Text("Anzahl")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    Stepper(value: $recipeVM.recipe.resultCount, in: 1...64) {
                        Text("×\(recipeVM.recipe.resultCount)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(accentTeal)
                    }
                    .controlSize(.mini)
                }
            }
        }
    }

    // MARK: - Item-Auswahl

    private var itemSelector: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ITEMS")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
            }

            // Custom Item-ID
            HStack(spacing: 4) {
                TextField("minecraft:...", text: $recipeVM.customItemID)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10, design: .monospaced))
                    .controlSize(.small)

                Button {
                    recipeVM.selectedItem = nil
                } label: {
                    Text("Custom")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(recipeVM.selectedItem == nil && !recipeVM.customItemID.isEmpty ? accentTeal : nil)
            }

            // Schnellauswahl-Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 4), spacing: 3) {
                ForEach(MinecraftItems.common) { item in
                    Button {
                        recipeVM.selectedItem = item
                        recipeVM.customItemID = ""
                    } label: {
                        VStack(spacing: 2) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 14, height: 14)
                            Text(item.name)
                                .font(.system(size: 6, weight: .medium))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(recipeVM.selectedItem?.id == item.id ? item.color.opacity(0.2) : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(recipeVM.selectedItem?.id == item.id ? item.color.opacity(0.5) : .clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - JSON Vorschau

    private var jsonPreview: some View {
        VStack(spacing: 6) {
            HStack {
                Text("JSON VORSCHAU")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()

                Button {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(recipeVM.exportJSON(), forType: .string)
                    #elseif os(iOS)
                    UIPasteboard.general.string = recipeVM.exportJSON()
                    #endif
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(accentTeal)
                .help("JSON kopieren")
            }

            ScrollView {
                Text(recipeVM.exportJSON())
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.3))
            )
        }
    }
}
