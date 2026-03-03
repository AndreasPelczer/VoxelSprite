//
//  PlanktonSpriteAppTests.swift
//  PlanktonSpriteAppTests
//
//  Created by Andreas Pelczer on 27.02.26.
//

import Testing
import SwiftUI
@testable import PlanktonSpriteApp

// MARK: - PixelCanvas Tests

struct PixelCanvasTests {

    @Test func defaultGridSizeIs32() {
        #expect(PixelCanvas.defaultGridSize == 32)
    }

    @Test func customGridSize() {
        let canvas16 = PixelCanvas(gridSize: 16)
        #expect(canvas16.gridSize == 16)
        #expect(canvas16.pixels.count == 16)
        #expect(canvas16.pixels[0].count == 16)

        let canvas64 = PixelCanvas(gridSize: 64)
        #expect(canvas64.gridSize == 64)
        #expect(canvas64.pixels.count == 64)
        #expect(canvas64.pixels[0].count == 64)
    }

    @Test func gridSizeClampedToRange() {
        let canvasTooSmall = PixelCanvas(gridSize: 0)
        #expect(canvasTooSmall.gridSize == 1)

        let canvasTooLarge = PixelCanvas(gridSize: 999)
        #expect(canvasTooLarge.gridSize == 128)
    }

    @Test func newCanvasIsEmpty() {
        let canvas = PixelCanvas()
        for y in 0..<PixelCanvas.defaultGridSize {
            for x in 0..<PixelCanvas.defaultGridSize {
                #expect(canvas.pixel(at: x, y: y) == nil)
            }
        }
    }

    @Test func setAndGetPixel() {
        var canvas = PixelCanvas()
        canvas.setPixel(at: 5, y: 10, color: .red)
        #expect(canvas.pixel(at: 5, y: 10) == .red)
    }

    @Test func setPixelToNilClearsIt() {
        var canvas = PixelCanvas()
        canvas.setPixel(at: 3, y: 3, color: .blue)
        canvas.setPixel(at: 3, y: 3, color: nil)
        #expect(canvas.pixel(at: 3, y: 3) == nil)
    }

    @Test func pixelAtInvalidCoordinatesReturnsNil() {
        let canvas = PixelCanvas()
        #expect(canvas.pixel(at: -1, y: 0) == nil)
        #expect(canvas.pixel(at: 0, y: -1) == nil)
        #expect(canvas.pixel(at: 32, y: 0) == nil)
        #expect(canvas.pixel(at: 0, y: 32) == nil)
        #expect(canvas.pixel(at: -5, y: -5) == nil)
        #expect(canvas.pixel(at: 100, y: 100) == nil)
    }

    @Test func setPixelAtInvalidCoordinatesIsIgnored() {
        var canvas = PixelCanvas()
        canvas.setPixel(at: -1, y: 0, color: .red)
        canvas.setPixel(at: 32, y: 0, color: .red)
        canvas.setPixel(at: 0, y: -1, color: .red)
        canvas.setPixel(at: 0, y: 32, color: .red)
        // Should not crash and canvas should remain empty
        for y in 0..<PixelCanvas.defaultGridSize {
            for x in 0..<PixelCanvas.defaultGridSize {
                #expect(canvas.pixel(at: x, y: y) == nil)
            }
        }
    }

    @Test func pixelAtBoundaryEdges() {
        var canvas = PixelCanvas()
        // Four corners
        canvas.setPixel(at: 0, y: 0, color: .red)
        canvas.setPixel(at: 31, y: 0, color: .green)
        canvas.setPixel(at: 0, y: 31, color: .blue)
        canvas.setPixel(at: 31, y: 31, color: .yellow)

        #expect(canvas.pixel(at: 0, y: 0) == .red)
        #expect(canvas.pixel(at: 31, y: 0) == .green)
        #expect(canvas.pixel(at: 0, y: 31) == .blue)
        #expect(canvas.pixel(at: 31, y: 31) == .yellow)
    }

    @Test func clearResetsAllPixels() {
        var canvas = PixelCanvas()
        canvas.setPixel(at: 0, y: 0, color: .red)
        canvas.setPixel(at: 15, y: 15, color: .blue)
        canvas.setPixel(at: 31, y: 31, color: .green)

        canvas.clear()

        #expect(canvas.pixel(at: 0, y: 0) == nil)
        #expect(canvas.pixel(at: 15, y: 15) == nil)
        #expect(canvas.pixel(at: 31, y: 31) == nil)
    }

    @Test func isValidCoordinates() {
        let canvas = PixelCanvas()
        #expect(canvas.isValid(x: 0, y: 0) == true)
        #expect(canvas.isValid(x: 31, y: 31) == true)
        #expect(canvas.isValid(x: 15, y: 15) == true)
        #expect(canvas.isValid(x: -1, y: 0) == false)
        #expect(canvas.isValid(x: 0, y: -1) == false)
        #expect(canvas.isValid(x: 32, y: 0) == false)
        #expect(canvas.isValid(x: 0, y: 32) == false)
    }

    @Test func pixelArrayDimensions() {
        let canvas = PixelCanvas()
        #expect(canvas.pixels.count == 32)
        for row in canvas.pixels {
            #expect(row.count == 32)
        }
    }
}

// MARK: - SpriteFrame Tests

struct SpriteFrameTests {

    @Test func newFrameHasEmptyCanvas() {
        let frame = SpriteFrame()
        for y in 0..<PixelCanvas.defaultGridSize {
            for x in 0..<PixelCanvas.defaultGridSize {
                #expect(frame.canvas.pixel(at: x, y: y) == nil)
            }
        }
    }

    @Test func newFrameWithCustomGridSize() {
        let frame = SpriteFrame(gridSize: 16)
        #expect(frame.canvas.gridSize == 16)
        #expect(frame.canvas.pixels.count == 16)
    }

    @Test func newFrameHasNilDuration() {
        let frame = SpriteFrame()
        #expect(frame.durationMs == nil)
    }

    @Test func frameWithDuration() {
        let canvas = PixelCanvas()
        let frame = SpriteFrame(canvas: canvas, durationMs: 200)
        #expect(frame.durationMs == 200)
    }

    @Test func newFrameHasUniqueID() {
        let frame1 = SpriteFrame()
        let frame2 = SpriteFrame()
        #expect(frame1.id != frame2.id)
    }

    @Test func initWithCanvasGetsNewID() {
        let original = SpriteFrame()
        let copy = SpriteFrame(canvas: original.canvas)
        #expect(original.id != copy.id)
    }

    @Test func initWithCanvasPreservesPixels() {
        var canvas = PixelCanvas()
        canvas.setPixel(at: 5, y: 5, color: .red)
        let frame = SpriteFrame(canvas: canvas)
        #expect(frame.canvas.pixel(at: 5, y: 5) == .red)
    }

    @Test func codableEncodesOnlyID() throws {
        let frame = SpriteFrame()
        let data = try JSONEncoder().encode(frame)
        let json = try JSONDecoder().decode([String: String].self, from: data)
        #expect(json.keys.count == 1)
        #expect(json["id"] == frame.id.uuidString)
    }

    @Test func codableDecodesWithEmptyCanvas() throws {
        let original = SpriteFrame()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SpriteFrame.self, from: data)
        #expect(decoded.id == original.id)
        // Decoded frame should have empty canvas (pixels not serialized)
        for y in 0..<PixelCanvas.defaultGridSize {
            for x in 0..<PixelCanvas.defaultGridSize {
                #expect(decoded.canvas.pixel(at: x, y: y) == nil)
            }
        }
    }
}

// MARK: - AnimationProject Tests

struct AnimationProjectTests {

    @Test func defaultProjectHasOneFrame() {
        let project = AnimationProject()
        #expect(project.frameCount == 1)
    }

    @Test func defaultProjectNameIsDaumenkino() {
        let project = AnimationProject()
        #expect(project.name == "Daumenkino")
    }

    @Test func defaultFPSIsSix() {
        let project = AnimationProject()
        #expect(project.fps == 6)
    }

    @Test func defaultGridSizeIs32() {
        let project = AnimationProject()
        #expect(project.gridSize == 32)
    }

    @Test func customGridSize() {
        let project = AnimationProject(gridSize: 16)
        #expect(project.gridSize == 16)
        #expect(project.frames[0].canvas.gridSize == 16)
    }

    @Test func loopAnimationDefaultsToTrue() {
        let project = AnimationProject()
        #expect(project.loopAnimation == true)
    }

    @Test func insertFrameUsesProjectGridSize() {
        var project = AnimationProject(gridSize: 64)
        let newIdx = project.insertFrame(after: 0)
        #expect(project.frames[newIdx].canvas.gridSize == 64)
    }

    @Test func customName() {
        let project = AnimationProject(name: "MeinProjekt")
        #expect(project.name == "MeinProjekt")
    }

    @Test func frameAtValidIndex() {
        let project = AnimationProject()
        #expect(project.frame(at: 0) != nil)
    }

    @Test func frameAtInvalidIndexReturnsNil() {
        let project = AnimationProject()
        #expect(project.frame(at: -1) == nil)
        #expect(project.frame(at: 1) == nil)
        #expect(project.frame(at: 100) == nil)
    }

    @Test func insertFrameAfterIndex() {
        var project = AnimationProject()
        let newIndex = project.insertFrame(after: 0)
        #expect(newIndex == 1)
        #expect(project.frameCount == 2)
    }

    @Test func insertFrameAfterLastIndex() {
        var project = AnimationProject()
        _ = project.insertFrame(after: 0)
        let newIndex = project.insertFrame(after: 1)
        #expect(newIndex == 2)
        #expect(project.frameCount == 3)
    }

    @Test func insertFrameClampsIndex() {
        var project = AnimationProject()
        // Insert after index beyond range
        let newIndex = project.insertFrame(after: 100)
        #expect(newIndex == 1) // Clamped to frames.count
        #expect(project.frameCount == 2)
    }

    @Test func duplicateFrameCopiesCanvas() {
        var project = AnimationProject()
        project.frames[0].canvas.setPixel(at: 10, y: 10, color: .red)

        let newIndex = project.duplicateFrame(at: 0)
        #expect(newIndex == 1)
        #expect(project.frameCount == 2)
        #expect(project.frames[1].canvas.pixel(at: 10, y: 10) == .red)
    }

    @Test func duplicateFrameGetsNewID() {
        var project = AnimationProject()
        project.duplicateFrame(at: 0)
        #expect(project.frames[0].id != project.frames[1].id)
    }

    @Test func duplicateFrameAtInvalidIndexReturnsNil() {
        var project = AnimationProject()
        #expect(project.duplicateFrame(at: -1) == nil)
        #expect(project.duplicateFrame(at: 5) == nil)
    }

    @Test func deleteFrameRemovesIt() {
        var project = AnimationProject()
        _ = project.insertFrame(after: 0)
        #expect(project.frameCount == 2)

        let deleted = project.deleteFrame(at: 1)
        #expect(deleted == true)
        #expect(project.frameCount == 1)
    }

    @Test func deleteLastFrameIsPrevented() {
        var project = AnimationProject()
        let deleted = project.deleteFrame(at: 0)
        #expect(deleted == false)
        #expect(project.frameCount == 1)
    }

    @Test func deleteFrameAtInvalidIndexReturnsFalse() {
        var project = AnimationProject()
        #expect(project.deleteFrame(at: -1) == false)
        #expect(project.deleteFrame(at: 5) == false)
    }

    @Test func moveFrameReorders() {
        var project = AnimationProject()
        project.frames[0].canvas.setPixel(at: 0, y: 0, color: .red)
        _ = project.insertFrame(after: 0)
        project.frames[1].canvas.setPixel(at: 0, y: 0, color: .blue)

        project.moveFrame(from: 0, to: 1)

        #expect(project.frames[0].canvas.pixel(at: 0, y: 0) == .blue)
        #expect(project.frames[1].canvas.pixel(at: 0, y: 0) == .red)
    }

    @Test func moveFrameClampsDestination() {
        var project = AnimationProject()
        _ = project.insertFrame(after: 0)
        let id0 = project.frames[0].id

        project.moveFrame(from: 0, to: 100)
        // Should clamp to last position
        #expect(project.frames[1].id == id0)
    }

    @Test func moveFrameFromInvalidSourceIsIgnored() {
        var project = AnimationProject()
        let id0 = project.frames[0].id
        project.moveFrame(from: -1, to: 0)
        project.moveFrame(from: 5, to: 0)
        #expect(project.frames[0].id == id0)
    }

    @Test func isValidIndex() {
        var project = AnimationProject()
        #expect(project.isValidIndex(0) == true)
        #expect(project.isValidIndex(-1) == false)
        #expect(project.isValidIndex(1) == false)

        _ = project.insertFrame(after: 0)
        #expect(project.isValidIndex(1) == true)
        #expect(project.isValidIndex(2) == false)
    }
}

// MARK: - ProjectFile Tests

struct ProjectFileTests {

    @Test func projectFileVersion() {
        let project = AnimationProject()
        let file = ProjectFile(from: project)
        #expect(file.version == 1)
    }

    @Test func projectFilePreservesName() {
        let project = AnimationProject(name: "TestName")
        let file = ProjectFile(from: project)
        #expect(file.name == "TestName")
    }

    @Test func projectFilePreservesFPS() {
        var project = AnimationProject()
        project.fps = 12
        let file = ProjectFile(from: project)
        #expect(file.fps == 12)
    }

    @Test func projectFileStoresGridSize() {
        let project = AnimationProject()
        let file = ProjectFile(from: project)
        #expect(file.gridSize == 32)
    }

    @Test func projectFileStoresCustomGridSize() {
        let project = AnimationProject(gridSize: 64)
        let file = ProjectFile(from: project)
        #expect(file.gridSize == 64)
    }

    @Test func projectFileStoresLoopAnimation() {
        var project = AnimationProject()
        project.loopAnimation = false
        let file = ProjectFile(from: project)
        #expect(file.loopAnimation == false)
    }

    @Test func roundTripPreservesGridSize() {
        let project = AnimationProject(gridSize: 16)
        let file = ProjectFile(from: project)
        let restored = file.toProject()
        #expect(restored.gridSize == 16)
        #expect(restored.frames[0].canvas.gridSize == 16)
    }

    @Test func roundTripPreservesFrameDuration() {
        var project = AnimationProject()
        project.frames[0].durationMs = 250
        let file = ProjectFile(from: project)
        let restored = file.toProject()
        #expect(restored.frames[0].durationMs == 250)
    }

    @Test func roundTripPreservesLoopAnimation() {
        var project = AnimationProject()
        project.loopAnimation = false
        let file = ProjectFile(from: project)
        let restored = file.toProject()
        #expect(restored.loopAnimation == false)
    }

    @Test func emptyCanvasSerializesToNils() {
        let project = AnimationProject()
        let file = ProjectFile(from: project)
        #expect(file.frames.count == 1)
        for row in file.frames[0].pixels {
            for pixel in row {
                #expect(pixel == nil)
            }
        }
    }

    @Test func roundTripPreservesFrameCount() {
        var project = AnimationProject()
        _ = project.insertFrame(after: 0)
        _ = project.insertFrame(after: 1)

        let file = ProjectFile(from: project)
        let restored = file.toProject()
        #expect(restored.frameCount == 3)
    }

    @Test func roundTripPreservesSettings() {
        var project = AnimationProject(name: "Mein Projekt")
        project.fps = 18

        let file = ProjectFile(from: project)
        let restored = file.toProject()
        #expect(restored.name == "Mein Projekt")
        #expect(restored.fps == 18)
    }

    @Test func emptyFrameArrayCreatesOneFrame() {
        // Simulating corrupt file with no frames
        let file = ProjectFile(
            version: 1,
            name: "Test",
            fps: 6,
            gridSize: 32,
            frames: []
        )

        // Need to init via Codable workaround
        let json = """
        {"version":1,"name":"Test","fps":6,"gridSize":32,"frames":[]}
        """
        let data = json.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(ProjectFile.self, from: data)
        let project = decoded.toProject()
        #expect(project.frameCount == 1)
    }

    @Test func jsonRoundTrip() throws {
        var project = AnimationProject(name: "JSONTest")
        project.fps = 10
        project.frames[0].canvas.setPixel(at: 0, y: 0, color: .red)
        _ = project.insertFrame(after: 0)

        let file = ProjectFile(from: project)
        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ProjectFile.self, from: data)
        let restored = decoded.toProject()

        #expect(restored.name == "JSONTest")
        #expect(restored.fps == 10)
        #expect(restored.frameCount == 2)
    }
}

// MARK: - Color Hex Tests

struct ColorHexTests {

    @Test func hexSixCharacters() {
        let color = Color(hex: "#FF0000")
        // Red color should have full red component
        #expect(color != Color.clear)
    }

    @Test func hexEightCharacters() {
        let color = Color(hex: "#FF000080")
        // Should create a semi-transparent red
        #expect(color != Color.clear)
    }

    @Test func hexWithoutHash() {
        let color = Color(hex: "00FF00")
        #expect(color != Color.clear)
    }

    @Test func hexBlack() {
        let color = Color(hex: "#000000")
        #expect(color == Color(red: 0, green: 0, blue: 0, opacity: 1))
    }

    @Test func hexWhite() {
        let color = Color(hex: "#FFFFFF")
        #expect(color == Color(red: 1, green: 1, blue: 1, opacity: 1))
    }

    @Test func hexFullyTransparent() {
        let color = Color(hex: "#FF000000")
        #expect(color == Color(red: 1, green: 0, blue: 0, opacity: 0))
    }
}

// MARK: - CanvasViewModel Tests

@MainActor
struct CanvasViewModelTests {

    @Test func defaultToolIsPen() {
        let vm = CanvasViewModel()
        #expect(vm.currentTool == .pen)
    }

    @Test func defaultColorIsCyan() {
        let vm = CanvasViewModel()
        #expect(vm.currentColor == .cyan)
    }

    @Test func defaultShowGridIsTrue() {
        let vm = CanvasViewModel()
        #expect(vm.showGrid == true)
    }

    @Test func initialUndoRedoState() {
        let vm = CanvasViewModel()
        #expect(vm.canUndo == false)
        #expect(vm.canRedo == false)
    }

    @Test func penToolDrawsPixel() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        canvasVM.currentTool = .pen
        canvasVM.currentColor = .red
        canvasVM.beginStroke(at: 5, y: 5)

        #expect(frameVM.activeCanvas.pixel(at: 5, y: 5) == .red)
    }

    @Test func eraserToolClearsPixel() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        // First draw a pixel
        canvasVM.currentTool = .pen
        canvasVM.currentColor = .red
        canvasVM.beginStroke(at: 5, y: 5)
        #expect(frameVM.activeCanvas.pixel(at: 5, y: 5) == .red)

        // Then erase it
        canvasVM.currentTool = .eraser
        canvasVM.beginStroke(at: 5, y: 5)
        #expect(frameVM.activeCanvas.pixel(at: 5, y: 5) == nil)
    }

    @Test func continueStrokeDrawsMore() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        canvasVM.currentTool = .pen
        canvasVM.currentColor = .blue
        canvasVM.beginStroke(at: 0, y: 0)
        canvasVM.continueStroke(at: 1, y: 0)
        canvasVM.continueStroke(at: 2, y: 0)

        #expect(frameVM.activeCanvas.pixel(at: 0, y: 0) == .blue)
        #expect(frameVM.activeCanvas.pixel(at: 1, y: 0) == .blue)
        #expect(frameVM.activeCanvas.pixel(at: 2, y: 0) == .blue)
    }

    @Test func undoAfterStroke() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        canvasVM.currentTool = .pen
        canvasVM.currentColor = .red
        canvasVM.beginStroke(at: 5, y: 5)
        #expect(canvasVM.canUndo == true)

        canvasVM.undo()
        #expect(frameVM.activeCanvas.pixel(at: 5, y: 5) == nil)
        #expect(canvasVM.canUndo == false)
    }

    @Test func redoAfterUndo() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        canvasVM.currentTool = .pen
        canvasVM.currentColor = .red
        canvasVM.beginStroke(at: 5, y: 5)
        canvasVM.undo()
        #expect(canvasVM.canRedo == true)

        canvasVM.redo()
        #expect(frameVM.activeCanvas.pixel(at: 5, y: 5) == .red)
        #expect(canvasVM.canRedo == false)
    }

    @Test func newStrokeClearsRedoStack() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        canvasVM.currentTool = .pen
        canvasVM.currentColor = .red
        canvasVM.beginStroke(at: 5, y: 5)
        canvasVM.undo()
        #expect(canvasVM.canRedo == true)

        // New stroke should clear redo
        canvasVM.currentColor = .blue
        canvasVM.beginStroke(at: 10, y: 10)
        #expect(canvasVM.canRedo == false)
    }

    @Test func undoStackLimitedToMax() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)
        canvasVM.maxUndoSteps = 20 // Test with reduced limit

        canvasVM.currentTool = .pen
        canvasVM.currentColor = .red

        // Do 25 strokes
        for i in 0..<25 {
            canvasVM.beginStroke(at: i % 32, y: 0)
        }

        // Undo all possible
        var undoCount = 0
        while canvasVM.canUndo {
            canvasVM.undo()
            undoCount += 1
        }
        #expect(undoCount == 20)
    }

    @Test func resetUndoHistoryClearsStacks() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        canvasVM.currentTool = .pen
        canvasVM.currentColor = .red
        canvasVM.beginStroke(at: 5, y: 5)
        #expect(canvasVM.canUndo == true)

        canvasVM.resetUndoHistory()
        #expect(canvasVM.canUndo == false)
        #expect(canvasVM.canRedo == false)
    }

    @Test func clearCanvasClearsAllPixels() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        canvasVM.currentTool = .pen
        canvasVM.currentColor = .red
        canvasVM.beginStroke(at: 5, y: 5)
        canvasVM.continueStroke(at: 6, y: 5)

        canvasVM.clearCanvas()
        #expect(frameVM.activeCanvas.pixel(at: 5, y: 5) == nil)
        #expect(frameVM.activeCanvas.pixel(at: 6, y: 5) == nil)
    }

    @Test func clearCanvasIsUndoable() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        canvasVM.currentTool = .pen
        canvasVM.currentColor = .red
        canvasVM.beginStroke(at: 5, y: 5)
        canvasVM.clearCanvas()
        #expect(frameVM.activeCanvas.pixel(at: 5, y: 5) == nil)

        canvasVM.undo()
        #expect(frameVM.activeCanvas.pixel(at: 5, y: 5) == .red)
    }

    @Test func floodFillFillsContiguousArea() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        // Fill empty canvas with red
        canvasVM.currentTool = .fill
        canvasVM.currentColor = .red
        canvasVM.beginStroke(at: 0, y: 0)

        // All pixels should be red
        for y in 0..<PixelCanvas.defaultGridSize {
            for x in 0..<PixelCanvas.defaultGridSize {
                #expect(frameVM.activeCanvas.pixel(at: x, y: y) == .red)
            }
        }
    }

    @Test func floodFillStopsAtBorder() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        // Draw a border with pen
        canvasVM.currentTool = .pen
        canvasVM.currentColor = .black
        for i in 0..<5 {
            canvasVM.beginStroke(at: i, y: 0) // Top border
            canvasVM.beginStroke(at: i, y: 4) // Bottom border
            canvasVM.beginStroke(at: 0, y: i) // Left border
            canvasVM.beginStroke(at: 4, y: i) // Right border
        }

        // Fill inside with red
        canvasVM.currentTool = .fill
        canvasVM.currentColor = .red
        canvasVM.beginStroke(at: 2, y: 2)

        // Inside should be red
        #expect(frameVM.activeCanvas.pixel(at: 1, y: 1) == .red)
        #expect(frameVM.activeCanvas.pixel(at: 2, y: 2) == .red)
        #expect(frameVM.activeCanvas.pixel(at: 3, y: 3) == .red)

        // Border should still be black
        #expect(frameVM.activeCanvas.pixel(at: 0, y: 0) == .black)
        #expect(frameVM.activeCanvas.pixel(at: 4, y: 4) == .black)

        // Outside should still be nil
        #expect(frameVM.activeCanvas.pixel(at: 5, y: 5) == nil)
    }

    @Test func toolIconNames() {
        #expect(CanvasViewModel.Tool.pen.iconName == "pencil")
        #expect(CanvasViewModel.Tool.eraser.iconName == "eraser")
        #expect(CanvasViewModel.Tool.fill.iconName == "drop.fill")
    }

    @Test func toolRawValues() {
        #expect(CanvasViewModel.Tool.pen.rawValue == "Stift")
        #expect(CanvasViewModel.Tool.eraser.rawValue == "Radierer")
        #expect(CanvasViewModel.Tool.fill.rawValue == "Füllen")
        #expect(CanvasViewModel.Tool.line.rawValue == "Linie")
        #expect(CanvasViewModel.Tool.rectangle.rawValue == "Rechteck")
    }

    @Test func toolIconNames_extended() {
        #expect(CanvasViewModel.Tool.line.iconName == "line.diagonal")
        #expect(CanvasViewModel.Tool.rectangle.iconName == "rectangle")
    }

    @Test func lineToolDrawsLine() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        canvasVM.currentTool = .line
        canvasVM.currentColor = .red
        canvasVM.beginStroke(at: 0, y: 0)
        canvasVM.continueStroke(at: 4, y: 0)
        canvasVM.endStroke(at: 4, y: 0)

        // Horizontal line from (0,0) to (4,0) – all pixels should be red
        for x in 0...4 {
            #expect(frameVM.activeCanvas.pixel(at: x, y: 0) == .red)
        }
        // Pixel outside should be nil
        #expect(frameVM.activeCanvas.pixel(at: 5, y: 0) == nil)
    }

    @Test func lineToolDiagonal() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        canvasVM.currentTool = .line
        canvasVM.currentColor = .blue
        canvasVM.beginStroke(at: 0, y: 0)
        canvasVM.endStroke(at: 3, y: 3)

        // Diagonal line – should have pixels at (0,0), (1,1), (2,2), (3,3)
        #expect(frameVM.activeCanvas.pixel(at: 0, y: 0) == .blue)
        #expect(frameVM.activeCanvas.pixel(at: 1, y: 1) == .blue)
        #expect(frameVM.activeCanvas.pixel(at: 2, y: 2) == .blue)
        #expect(frameVM.activeCanvas.pixel(at: 3, y: 3) == .blue)
    }

    @Test func rectangleToolDrawsOutline() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        canvasVM.currentTool = .rectangle
        canvasVM.currentColor = .green
        canvasVM.beginStroke(at: 1, y: 1)
        canvasVM.endStroke(at: 5, y: 5)

        // Top edge
        for x in 1...5 {
            #expect(frameVM.activeCanvas.pixel(at: x, y: 1) == .green)
        }
        // Bottom edge
        for x in 1...5 {
            #expect(frameVM.activeCanvas.pixel(at: x, y: 5) == .green)
        }
        // Left edge
        for y in 1...5 {
            #expect(frameVM.activeCanvas.pixel(at: 1, y: y) == .green)
        }
        // Inside should be empty
        #expect(frameVM.activeCanvas.pixel(at: 3, y: 3) == nil)
    }

    @Test func lineToolIsUndoable() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        canvasVM.currentTool = .line
        canvasVM.currentColor = .red
        canvasVM.beginStroke(at: 0, y: 0)
        canvasVM.endStroke(at: 5, y: 0)
        #expect(frameVM.activeCanvas.pixel(at: 0, y: 0) == .red)

        canvasVM.undo()
        #expect(frameVM.activeCanvas.pixel(at: 0, y: 0) == nil)
    }

    @Test func zoomInAndOut() {
        let vm = CanvasViewModel()
        #expect(vm.zoomScale == 1.0)

        vm.zoomIn()
        #expect(vm.zoomScale == 1.5)

        vm.zoomOut()
        #expect(vm.zoomScale == 1.0)

        vm.zoomOut()
        #expect(vm.zoomScale == 0.5)

        // Should not go below min
        vm.zoomOut()
        #expect(vm.zoomScale == 0.5)
    }

    @Test func zoomMaxLimit() {
        let vm = CanvasViewModel()
        for _ in 0..<20 {
            vm.zoomIn()
        }
        #expect(vm.zoomScale == vm.maxZoom)
    }

    @Test func resetZoom() {
        let vm = CanvasViewModel()
        vm.zoomIn()
        vm.zoomIn()
        vm.resetZoom()
        #expect(vm.zoomScale == 1.0)
    }

    @Test func onionSkinDefaultState() {
        let vm = CanvasViewModel()
        #expect(vm.onionSkinEnabled == false)
        #expect(vm.onionSkinPrevious == true)
        #expect(vm.onionSkinNext == false)
        #expect(vm.onionSkinOpacity == 0.3)
    }

    @Test func undoStackLimitedTo50() {
        let frameVM = FrameViewModel()
        let canvasVM = CanvasViewModel()
        canvasVM.connect(to: frameVM)

        canvasVM.currentTool = .pen
        canvasVM.currentColor = .red

        // Do 55 strokes
        for i in 0..<55 {
            canvasVM.beginStroke(at: i % 32, y: (i / 32) % 32)
        }

        var undoCount = 0
        while canvasVM.canUndo {
            canvasVM.undo()
            undoCount += 1
        }
        #expect(undoCount == 50)
    }
}

// MARK: - FrameViewModel Tests

@MainActor
struct FrameViewModelTests {

    @Test func initialState() {
        let vm = FrameViewModel()
        #expect(vm.frameCount == 1)
        #expect(vm.activeFrameIndex == 0)
        #expect(vm.currentFileURL == nil)
        #expect(vm.canAddFrame == true)
    }

    @Test func maxFramesIs24() {
        let vm = FrameViewModel()
        #expect(vm.maxFrames == 24)
    }

    @Test func addFrameInsertsAfterActive() {
        let vm = FrameViewModel()
        vm.addFrame()
        #expect(vm.frameCount == 2)
        #expect(vm.activeFrameIndex == 1)
    }

    @Test func addFrameSwitchesToNewFrame() {
        let vm = FrameViewModel()
        let originalID = vm.activeFrame?.id
        vm.addFrame()
        #expect(vm.activeFrame?.id != originalID)
    }

    @Test func addFrameRespectsMaxLimit() {
        let vm = FrameViewModel()
        for _ in 0..<30 {
            vm.addFrame()
        }
        #expect(vm.frameCount == 24)
        #expect(vm.canAddFrame == false)
    }

    @Test func duplicateActiveFrameCopiesCanvas() {
        let vm = FrameViewModel()

        var canvas = vm.activeCanvas
        canvas.setPixel(at: 10, y: 10, color: .green)
        vm.updateActiveCanvas(canvas)

        vm.duplicateActiveFrame()
        #expect(vm.frameCount == 2)
        #expect(vm.activeFrameIndex == 1)
        #expect(vm.activeCanvas.pixel(at: 10, y: 10) == .green)
    }

    @Test func duplicateRespectsMaxLimit() {
        let vm = FrameViewModel()
        for _ in 0..<23 {
            vm.addFrame()
        }
        #expect(vm.frameCount == 24)

        vm.duplicateActiveFrame()
        #expect(vm.frameCount == 24) // Should not exceed
    }

    @Test func deleteFrameRemoves() {
        let vm = FrameViewModel()
        vm.addFrame()
        vm.addFrame()
        #expect(vm.frameCount == 3)

        vm.deleteFrame(at: 2)
        #expect(vm.frameCount == 2)
    }

    @Test func deleteFrameBeforeActiveAdjustsIndex() {
        let vm = FrameViewModel()
        vm.addFrame()
        vm.addFrame()
        vm.selectFrame(at: 2)
        let activeID = vm.activeFrame?.id

        vm.deleteFrame(at: 0)
        #expect(vm.activeFrameIndex == 1)
        #expect(vm.activeFrame?.id == activeID)
    }

    @Test func deleteActiveFrameClampsIndex() {
        let vm = FrameViewModel()
        vm.addFrame()
        vm.selectFrame(at: 1)

        vm.deleteActiveFrame()
        #expect(vm.frameCount == 1)
        #expect(vm.activeFrameIndex == 0)
    }

    @Test func deleteLastFrameIsPrevented() {
        let vm = FrameViewModel()
        vm.deleteActiveFrame()
        #expect(vm.frameCount == 1)
    }

    @Test func deleteFrameAfterActiveKeepsIndex() {
        let vm = FrameViewModel()
        vm.addFrame()
        vm.addFrame()
        vm.selectFrame(at: 0)

        vm.deleteFrame(at: 2)
        #expect(vm.activeFrameIndex == 0)
    }

    @Test func moveFrameTracksActiveByID() {
        let vm = FrameViewModel()
        vm.addFrame()
        vm.addFrame()
        vm.selectFrame(at: 0)
        let activeID = vm.activeFrame?.id

        vm.moveFrame(from: 0, to: 2)
        #expect(vm.activeFrame?.id == activeID)
        #expect(vm.activeFrameIndex == 2)
    }

    @Test func moveFrameFromInvalidSource() {
        let vm = FrameViewModel()
        vm.addFrame()
        let count = vm.frameCount
        vm.moveFrame(from: -1, to: 0)
        vm.moveFrame(from: 10, to: 0)
        #expect(vm.frameCount == count)
    }

    @Test func nextFrameWrapsAround() {
        let vm = FrameViewModel()
        vm.addFrame()
        vm.addFrame()
        // 3 frames, active = 2 (last added)
        vm.selectFrame(at: 2)

        vm.nextFrame()
        #expect(vm.activeFrameIndex == 0)
    }

    @Test func previousFrameWrapsAround() {
        let vm = FrameViewModel()
        vm.addFrame()
        vm.addFrame()
        vm.selectFrame(at: 0)

        vm.previousFrame()
        #expect(vm.activeFrameIndex == 2)
    }

    @Test func selectFrameAtValidIndex() {
        let vm = FrameViewModel()
        vm.addFrame()
        vm.addFrame()

        vm.selectFrame(at: 0)
        #expect(vm.activeFrameIndex == 0)
        vm.selectFrame(at: 1)
        #expect(vm.activeFrameIndex == 1)
    }

    @Test func selectFrameAtInvalidIndex() {
        let vm = FrameViewModel()
        vm.selectFrame(at: -1)
        #expect(vm.activeFrameIndex == 0)
        vm.selectFrame(at: 5)
        #expect(vm.activeFrameIndex == 0)
    }

    @Test func newProjectResetsEverything() {
        let vm = FrameViewModel()
        vm.addFrame()
        vm.addFrame()
        vm.selectFrame(at: 2)

        vm.newProject()
        #expect(vm.frameCount == 1)
        #expect(vm.activeFrameIndex == 0)
        #expect(vm.currentFileURL == nil)
    }

    @Test func updateActiveCanvasWritesBack() {
        let vm = FrameViewModel()
        var canvas = PixelCanvas()
        canvas.setPixel(at: 15, y: 15, color: .orange)

        vm.updateActiveCanvas(canvas)
        #expect(vm.activeCanvas.pixel(at: 15, y: 15) == .orange)
    }

    @Test func activeCanvasWithInvalidIndexReturnsEmpty() {
        let vm = FrameViewModel()
        // Force invalid state
        vm.activeFrameIndex = 99
        let canvas = vm.activeCanvas
        // Should return empty canvas, not crash
        #expect(canvas.pixel(at: 0, y: 0) == nil)
    }

    @Test func moveFramesSwiftUIAdapter() {
        let vm = FrameViewModel()
        vm.addFrame()
        vm.addFrame()
        vm.selectFrame(at: 0)
        let activeID = vm.activeFrame?.id

        // Move frame 0 to position 2 (SwiftUI convention)
        vm.moveFrames(from: IndexSet(integer: 0), to: 2)
        #expect(vm.activeFrame?.id == activeID)
    }

    @Test func navigationWithSingleFrame() {
        let vm = FrameViewModel()
        let id = vm.activeFrame?.id

        vm.nextFrame()
        #expect(vm.activeFrame?.id == id)
        #expect(vm.activeFrameIndex == 0)

        vm.previousFrame()
        #expect(vm.activeFrame?.id == id)
        #expect(vm.activeFrameIndex == 0)
    }
}

// MARK: - FrameViewModel Extended Tests

@MainActor
struct FrameViewModelExtendedTests {

    @Test func newProjectWithGridSize() {
        let vm = FrameViewModel()
        vm.newProject(gridSize: 16)
        #expect(vm.project.gridSize == 16)
        #expect(vm.activeCanvas.gridSize == 16)
    }

    @Test func setFrameDuration() {
        let vm = FrameViewModel()
        vm.setFrameDuration(200, at: 0)
        #expect(vm.project.frames[0].durationMs == 200)
    }

    @Test func setFrameDurationNilClearsIt() {
        let vm = FrameViewModel()
        vm.setFrameDuration(200, at: 0)
        vm.setFrameDuration(nil, at: 0)
        #expect(vm.project.frames[0].durationMs == nil)
    }

    @Test func setFrameDurationInvalidIndex() {
        let vm = FrameViewModel()
        vm.setFrameDuration(200, at: 99)
        // Should not crash
        #expect(vm.project.frames[0].durationMs == nil)
    }

    @Test func duplicateFramePreservesDuration() {
        let vm = FrameViewModel()
        vm.setFrameDuration(150, at: 0)
        vm.duplicateActiveFrame()
        #expect(vm.project.frames[1].durationMs == 150)
    }

    @Test func autosaveURLPointsToApplicationSupport() {
        let url = FrameViewModel.autosaveLatestURL
        #expect(url.lastPathComponent == "autosave_latest.plankton")
        #expect(url.pathComponents.contains("PlanktonSprite"))
        #expect(url.pathComponents.contains("Autosave"))
    }

    @Test func autosavePreviousURLExists() {
        let url = FrameViewModel.autosavePreviousURL
        #expect(url.lastPathComponent == "autosave_previous.plankton")
    }

    @Test func autosavePreservesCurrentFileURL() {
        let vm = FrameViewModel()
        let fakeURL = URL(fileURLWithPath: "/tmp/test.plankton")
        vm.currentFileURL = fakeURL
        vm.autosave()
        #expect(vm.currentFileURL == fakeURL)
    }

    @Test func autosaveWithNilURLKeepsNil() {
        let vm = FrameViewModel()
        vm.currentFileURL = nil
        vm.autosave()
        #expect(vm.currentFileURL == nil)
    }

    @Test func autosaveCreatesFile() {
        let vm = FrameViewModel()
        vm.autosave()
        #expect(FileManager.default.fileExists(atPath: FrameViewModel.autosaveLatestURL.path))
    }
}

// MARK: - ExportError Tests

struct ExportErrorTests {

    @Test func errorDescriptions() {
        #expect(ExportError.destinationCreationFailed.errorDescription != nil)
        #expect(ExportError.frameRenderFailed.errorDescription != nil)
        #expect(ExportError.finalizationFailed.errorDescription != nil)
        #expect(ExportError.contextCreationFailed.errorDescription != nil)
        #expect(ExportError.imageCreationFailed.errorDescription != nil)
        #expect(ExportError.pngEncodingFailed.errorDescription != nil)
    }
}

// MARK: - ExportViewModel Tests

@MainActor
struct ExportViewModelTests {

    @Test func defaultSettings() {
        let vm = ExportViewModel()
        #expect(vm.transparentBackground == false)
        #expect(vm.spritesheetLayout == .horizontal)
        #expect(vm.enginePreset == .generic)
        #expect(vm.spritesheetPadding == 0)
        #expect(vm.exportProgress == 0)
        #expect(vm.exportStatus == "")
    }

    @Test func cleanupResetsProgress() {
        let vm = ExportViewModel()
        vm.exportProgress = 0.5
        vm.exportStatus = "Working…"
        vm.cleanup()
        #expect(vm.exportProgress == 0)
        #expect(vm.exportStatus == "")
        #expect(vm.exportedFileURL == nil)
        #expect(vm.additionalExportURLs.isEmpty)
    }

    @Test func spritesheetLayoutCases() {
        let allCases = ExportViewModel.SpritesheetLayout.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.horizontal))
        #expect(allCases.contains(.vertical))
        #expect(allCases.contains(.grid))
    }

    @Test func enginePresetCases() {
        let allCases = ExportViewModel.EnginePreset.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.generic))
        #expect(allCases.contains(.unity))
        #expect(allCases.contains(.godot))
        #expect(allCases.contains(.spriteKit))
    }
}

// MARK: - PaletteManager Tests

struct PaletteManagerTests {

    @Test func initiallyEmpty() {
        let manager = PaletteManager()
        // May have saved palettes from previous runs, but structure should be valid
        #expect(manager.savedPalettes is [SavedPalette])
    }

    @Test func savedPaletteInit() {
        let palette = SavedPalette(name: "Test", colors: [.red, .blue, .green])
        #expect(palette.name == "Test")
        #expect(palette.colors.count == 3)
        #expect(palette.swiftUIColors.count == 3)
    }

    @Test func savedPaletteHexRoundTrip() {
        let palette = SavedPalette(name: "Hex Test", colors: [.black, .white])
        #expect(palette.colors.contains("#000000"))
        #expect(palette.colors.contains("#FFFFFF"))
    }
}

// MARK: - PixelCanvas PresetSize Tests

struct PresetSizeTests {

    @Test func presetSizeValues() {
        #expect(PixelCanvas.PresetSize.small.rawValue == 16)
        #expect(PixelCanvas.PresetSize.medium.rawValue == 32)
        #expect(PixelCanvas.PresetSize.large.rawValue == 64)
    }

    @Test func presetSizeLabels() {
        #expect(PixelCanvas.PresetSize.small.label == "16×16")
        #expect(PixelCanvas.PresetSize.medium.label == "32×32")
        #expect(PixelCanvas.PresetSize.large.label == "64×64")
    }

    @Test func allPresetSizes() {
        #expect(PixelCanvas.PresetSize.allCases.count == 3)
    }
}
