//
//  SceneKitPreviewView.swift
//  VoxelSprite
//
//  Echter 3D-Würfel mit SceneKit.
//  Zeigt alle 6 Face-Texturen auf einem drehbaren Würfel.
//  Pixel-Art bleibt scharf durch Nearest-Neighbor-Filtering.
//  Unterstützt direktes Malen auf dem 3D-Modell.
//

import SwiftUI
import SceneKit
import Combine

// MARK: - Block Cube Preview

struct SceneKitPreviewView: View {

    @EnvironmentObject var blockVM: BlockViewModel
    @EnvironmentObject var canvasVM: CanvasViewModel

    /// Grid auf dem 3D-Modell anzeigen
    var showGrid: Bool = false

    /// Malen auf dem 3D-Modell aktivieren
    var paintEnabled: Bool = false

    @State private var scene: SCNScene = SCNScene()
    @State private var sceneReady = false
    @StateObject private var orbitState: OrbitCameraState = {
        let state = OrbitCameraState()
        state.azimuth = 0.78      // ~45°
        state.elevation = 0.55
        state.distance = 3.1
        return state
    }()
    @State private var strokeStarted = false

    var body: some View {
        Group {
            if paintEnabled {
                PaintableSceneView(
                    scene: scene,
                    onPaintHit: handlePaintHit,
                    onPaintEnd: handlePaintEnd,
                    orbitState: orbitState
                )
            } else {
                NonPaintableBlockView(project: blockVM.project, showGrid: showGrid, activeFace: blockVM.activeFaceType)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            if paintEnabled && !sceneReady {
                setupScene()
                sceneReady = true
            }
        }
        .onChange(of: blockVM.project.name) {
            if paintEnabled { updateMaterials() }
        }
        .onChange(of: showGrid) {
            if paintEnabled { updateMaterials() }
        }
        // Materialien bei jeder Projektänderung updaten
        .onReceive(blockVM.objectWillChange) {
            if paintEnabled { updateMaterials() }
        }
    }

    // MARK: - Scene Setup

    private func setupScene() {
        let bgColor: Any = {
            #if os(macOS)
            return NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
            #else
            return UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
            #endif
        }()

        scene.background.contents = bgColor

        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        box.materials = Self.createMaterials(project: blockVM.project, showGrid: showGrid, activeFace: blockVM.activeFaceType)
        let cubeNode = SCNNode(geometry: box)
        cubeNode.name = "cube"
        scene.rootNode.addChildNode(cubeNode)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 35
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)
        orbitState.center = SCNVector3(0, 0, 0)
        orbitState.updateCamera(cameraNode)

        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.intensity = 400
        scene.rootNode.addChildNode(ambientNode)

        let directionalNode = SCNNode()
        directionalNode.light = SCNLight()
        directionalNode.light?.type = .directional
        directionalNode.light?.intensity = 600
        directionalNode.position = SCNVector3(2, 4, 2)
        directionalNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalNode)
    }

    private func updateMaterials() {
        guard let cubeNode = scene.rootNode.childNode(withName: "cube", recursively: true),
              let box = cubeNode.geometry as? SCNBox else { return }
        box.materials = Self.createMaterials(project: blockVM.project, showGrid: showGrid, activeFace: blockVM.activeFaceType)
    }

    // MARK: - Paint Handling

    /// SCNBox Face-Index → FaceType Mapping
    /// SCNBox: 0=+X(East), 1=-X(West), 2=+Y(Top), 3=-Y(Bottom), 4=+Z(North), 5=-Z(South)
    private static let boxFaceToFaceType: [FaceType] = [.east, .west, .top, .bottom, .north, .south]

    private func handlePaintHit(nodeName: String, faceIndex: Int, uv: CGPoint) {
        guard nodeName == "cube",
              faceIndex >= 0, faceIndex < Self.boxFaceToFaceType.count else { return }

        let faceType = Self.boxFaceToFaceType[faceIndex]
        let canvas = blockVM.project.canvas(for: faceType)

        // UV → Pixel-Koordinaten
        let px = Int(uv.x * CGFloat(canvas.width))
        let py = Int((1.0 - uv.y) * CGFloat(canvas.height)) // Y ist invertiert
        let clampedX = max(0, min(canvas.width - 1, px))
        let clampedY = max(0, min(canvas.height - 1, py))

        // Zur richtigen Face wechseln und malen
        if blockVM.activeFaceType != faceType {
            blockVM.selectFace(faceType)
            canvasVM.resetUndoHistory()
        }

        if !strokeStarted {
            canvasVM.beginStroke(at: clampedX, y: clampedY)
            strokeStarted = true
        } else {
            canvasVM.continueStroke(at: clampedX, y: clampedY)
        }
    }

    private func handlePaintEnd() {
        if strokeStarted {
            // Canvas-Koordinaten sind nicht mehr relevant, endStroke mit letzter Position
            canvasVM.endStroke(at: 0, y: 0)
            strokeStarted = false
        }
    }

    // MARK: - Materials

    // DEBUG: Nummerierte Farbflächen um SCNBox Face-Reihenfolge zu bestimmen
    private static func debugImage(index: Int, size: Int = 64) -> CGImage? {
        let colors: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
            (1.0, 0.0, 0.0),  // 0 = Rot
            (0.0, 1.0, 0.0),  // 1 = Grün
            (0.0, 0.0, 1.0),  // 2 = Blau
            (1.0, 1.0, 0.0),  // 3 = Gelb
            (0.0, 1.0, 1.0),  // 4 = Cyan
            (1.0, 0.0, 1.0),  // 5 = Magenta
        ]
        let c = colors[index]
        guard let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(red: c.r, green: c.g, blue: c.b, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        // Nummer zeichnen
        ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        let numSize = size / 2
        let offset = size / 4
        // Einfaches Kreuz/Muster für die Nummer: index Anzahl schwarzer Blöcke
        for i in 0...index {
            let bx = offset + (i % 3) * (numSize / 3)
            let by = offset + (i / 3) * (numSize / 3)
            ctx.fill(CGRect(x: bx, y: by, width: numSize / 4, height: numSize / 4))
        }
        return ctx.makeImage()
    }

    static func createMaterials(project: BlockProject, showGrid: Bool, activeFace: FaceType? = nil) -> [SCNMaterial] {
        let faceOrder: [FaceType] = [.east, .west, .top, .bottom, .north, .south]
        return faceOrder.enumerated().map { (index, faceType) in
            let material = SCNMaterial()
            // DEBUG: Nummerierte Farben statt Texturen
            if let debugImg = debugImage(index: index) {
                material.diffuse.contents = debugImg
                material.diffuse.magnificationFilter = .nearest
                material.diffuse.minificationFilter = .nearest
                material.diffuse.wrapS = .clamp
                material.diffuse.wrapT = .clamp
            }
            material.lightingModel = .blinn
            material.isDoubleSided = false
            return material
        }
    }
}

// MARK: - Non-Paintable View (für read-only Modus)

#if os(macOS)

private struct NonPaintableBlockView: NSViewRepresentable {
    let project: BlockProject
    var showGrid: Bool = false
    var activeFace: FaceType = .north

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scnView.antialiasingMode = .none
        scnView.scene = Self.createScene()
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        guard let cubeNode = scnView.scene?.rootNode.childNode(withName: "cube", recursively: true),
              let box = cubeNode.geometry as? SCNBox else { return }
        box.materials = SceneKitPreviewView.createMaterials(project: project, showGrid: showGrid, activeFace: activeFace)
    }

    static func createScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        let cubeNode = SCNNode(geometry: box)
        cubeNode.name = "cube"
        scene.rootNode.addChildNode(cubeNode)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 35
        cameraNode.position = SCNVector3(1.8, 1.4, 1.8)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)

        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.intensity = 400
        scene.rootNode.addChildNode(ambientNode)

        let directionalNode = SCNNode()
        directionalNode.light = SCNLight()
        directionalNode.light?.type = .directional
        directionalNode.light?.intensity = 600
        directionalNode.position = SCNVector3(2, 4, 2)
        directionalNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalNode)

        return scene
    }
}

#elseif os(iOS)

private struct NonPaintableBlockView: UIViewRepresentable {
    let project: BlockProject
    var showGrid: Bool = false
    var activeFace: FaceType = .north

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scnView.antialiasingMode = .none
        scnView.scene = Self.createScene()
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        guard let cubeNode = scnView.scene?.rootNode.childNode(withName: "cube", recursively: true),
              let box = cubeNode.geometry as? SCNBox else { return }
        box.materials = SceneKitPreviewView.createMaterials(project: project, showGrid: showGrid, activeFace: activeFace)
    }

    static func createScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        let cubeNode = SCNNode(geometry: box)
        cubeNode.name = "cube"
        scene.rootNode.addChildNode(cubeNode)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 35
        cameraNode.position = SCNVector3(1.8, 1.4, 1.8)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)

        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.intensity = 400
        scene.rootNode.addChildNode(ambientNode)

        let directionalNode = SCNNode()
        directionalNode.light = SCNLight()
        directionalNode.light?.type = .directional
        directionalNode.light?.intensity = 600
        directionalNode.position = SCNVector3(2, 4, 2)
        directionalNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalNode)

        return scene
    }
}

#endif
