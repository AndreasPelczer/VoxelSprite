//
//  AndyPreviewView.swift
//  VoxelSprite
//
//  3D-Vorschau von Andy/Alex mit SceneKit.
//  Baut den Charakter aus 6 Box-Geometrien (Kopf, Körper, Arme, Beine).
//  Base + Overlay Layer werden als Texturen angewendet.
//  Unterstützt direktes Malen auf dem 3D-Modell.
//

import SwiftUI
import SceneKit
import Combine

struct AndyPreviewView: View {

    @EnvironmentObject var skinVM: SkinViewModel
    @EnvironmentObject var canvasVM: CanvasViewModel

    /// Grid auf dem 3D-Modell anzeigen
    var showGrid: Bool = false

    /// Malen auf dem 3D-Modell aktivieren
    var paintEnabled: Bool = false

    @State private var scene: SCNScene = SCNScene()
    @State private var sceneReady = false
    @StateObject private var orbitState: OrbitCameraState = {
        let state = OrbitCameraState()
        state.azimuth = 0.5
        state.elevation = 0.35
        state.distance = 6.5
        state.center = SCNVector3(0, 1.8, 0)
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
                NonPaintableAndyView(project: skinVM.project, showGrid: showGrid, activeBodyPart: skinVM.activeBodyPart, activeFace: skinVM.activeFace)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .aspectRatio(0.85, contentMode: .fit)
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
        .onReceive(skinVM.objectWillChange) {
            if paintEnabled { updateMaterials() }
        }
        .onChange(of: showGrid) {
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

        for part in andyParts {
            let box = SCNBox(
                width: CGFloat(part.scnSize.x),
                height: CGFloat(part.scnSize.y),
                length: CGFloat(part.scnSize.z),
                chamferRadius: 0
            )
            box.materials = Self.materialsForPart(part.bodyPart, project: skinVM.project, showGrid: showGrid, activeBodyPart: skinVM.activeBodyPart, activeFace: skinVM.activeFace)
            let node = SCNNode(geometry: box)
            node.name = part.name
            node.position = part.position
            node.opacity = part.bodyPart == skinVM.activeBodyPart ? 1.0 : 0.7
            scene.rootNode.addChildNode(node)
        }

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 35
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)
        orbitState.updateCamera(cameraNode)

        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.intensity = 500
        scene.rootNode.addChildNode(ambientNode)

        let dirNode = SCNNode()
        dirNode.light = SCNLight()
        dirNode.light?.type = .directional
        dirNode.light?.intensity = 500
        dirNode.position = SCNVector3(3, 5, 3)
        dirNode.look(at: SCNVector3(0, 2, 0))
        scene.rootNode.addChildNode(dirNode)
    }

    private func updateMaterials() {
        for part in andyParts {
            if let node = scene.rootNode.childNode(withName: part.name, recursively: true),
               let box = node.geometry as? SCNBox {
                box.materials = Self.materialsForPart(part.bodyPart, project: skinVM.project, showGrid: showGrid, activeBodyPart: skinVM.activeBodyPart, activeFace: skinVM.activeFace)
                node.opacity = part.bodyPart == skinVM.activeBodyPart ? 1.0 : 0.7
            }
        }
    }

    // MARK: - Paint Handling

    /// SCNBox Face-Index → SkinFace Mapping
    /// SCNBox: 0=+X(Right), 1=-X(Left), 2=+Y(Top), 3=-Y(Bottom), 4=+Z(Front), 5=-Z(Back)
    private static let boxFaceToSkinFace: [SkinFace] = [.right, .left, .top, .bottom, .front, .back]

    /// Node-Name → SkinBodyPart Mapping
    private static let nodeNameToBodyPart: [String: SkinBodyPart] = [
        "head": .head, "body": .body,
        "rightArm": .rightArm, "leftArm": .leftArm,
        "rightLeg": .rightLeg, "leftLeg": .leftLeg
    ]

    private func handlePaintHit(nodeName: String, faceIndex: Int, uv: CGPoint) {
        guard let bodyPart = Self.nodeNameToBodyPart[nodeName],
              faceIndex >= 0, faceIndex < Self.boxFaceToSkinFace.count else { return }

        let face = Self.boxFaceToSkinFace[faceIndex]

        // Zur richtigen Auswahl wechseln
        if skinVM.activeBodyPart != bodyPart {
            skinVM.selectBodyPart(bodyPart)
            canvasVM.resetUndoHistory()
        }
        if skinVM.activeFace != face {
            skinVM.selectFace(face)
            canvasVM.resetUndoHistory()
        }

        let canvas = skinVM.activeCanvas

        // UV → Pixel
        let px = Int(uv.x * CGFloat(canvas.width))
        let py = Int((1.0 - uv.y) * CGFloat(canvas.height))
        let clampedX = max(0, min(canvas.width - 1, px))
        let clampedY = max(0, min(canvas.height - 1, py))

        if !strokeStarted {
            canvasVM.beginStroke(at: clampedX, y: clampedY)
            strokeStarted = true
        } else {
            canvasVM.continueStroke(at: clampedX, y: clampedY)
        }
    }

    private func handlePaintEnd() {
        if strokeStarted {
            canvasVM.endStroke(at: 0, y: 0)
            strokeStarted = false
        }
    }

    // MARK: - Materials

    static func materialsForPart(_ bodyPart: SkinBodyPart, project: SkinProject, showGrid: Bool = false, activeBodyPart: SkinBodyPart? = nil, activeFace: SkinFace? = nil) -> [SCNMaterial] {
        let faceOrder: [SkinFace] = [.right, .left, .top, .bottom, .front, .back]
        let isActivePart = activeBodyPart != nil && bodyPart == activeBodyPart
        return faceOrder.map { face in
            let material = SCNMaterial()
            let baseCanvas = project.extractRegion(bodyPart: bodyPart, face: face, layer: .base)
            if let baseImage = baseCanvas.toCGImage(showGrid: showGrid) {
                let overlayCanvas = project.extractRegion(bodyPart: bodyPart, face: face, layer: .overlay)
                if let overlayImage = overlayCanvas.toCGImage(showGrid: showGrid) {
                    let composited = Self.compositeImages(base: baseImage, overlay: overlayImage,
                                                          width: baseCanvas.width, height: baseCanvas.height)
                    material.diffuse.contents = composited ?? baseImage
                } else {
                    material.diffuse.contents = baseImage
                }
            }
            material.diffuse.magnificationFilter = .nearest
            material.diffuse.minificationFilter = .nearest
            material.diffuse.wrapS = .clamp
            material.diffuse.wrapT = .clamp
            material.lightingModel = .blinn
            material.isDoubleSided = false
            // Aktive Seite des aktiven Körperteils hervorheben
            if isActivePart, let activeFace = activeFace, face == activeFace {
                #if os(macOS)
                material.emission.contents = NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0)
                #else
                material.emission.contents = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0)
                #endif
                material.emission.intensity = 0.3
            }
            return material
        }
    }

    static func compositeImages(base: CGImage, overlay: CGImage, width: Int, height: Int) -> CGImage? {
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        ctx.draw(base, in: rect)
        ctx.draw(overlay, in: rect)
        return ctx.makeImage()
    }
}

// MARK: - Andy Body Part Definition

private struct AndyPartDef {
    let bodyPart: SkinBodyPart
    let scnSize: SCNVector3
    let position: SCNVector3
    let name: String
}

private let andyParts: [AndyPartDef] = [
    AndyPartDef(bodyPart: .head, scnSize: SCNVector3(1, 1, 1), position: SCNVector3(0, 3.25, 0), name: "head"),
    AndyPartDef(bodyPart: .body, scnSize: SCNVector3(1, 1.5, 0.5), position: SCNVector3(0, 2, 0), name: "body"),
    AndyPartDef(bodyPart: .rightArm, scnSize: SCNVector3(0.5, 1.5, 0.5), position: SCNVector3(0.75, 2, 0), name: "rightArm"),
    AndyPartDef(bodyPart: .leftArm, scnSize: SCNVector3(0.5, 1.5, 0.5), position: SCNVector3(-0.75, 2, 0), name: "leftArm"),
    AndyPartDef(bodyPart: .rightLeg, scnSize: SCNVector3(0.5, 1.5, 0.5), position: SCNVector3(0.25, 0.5, 0), name: "rightLeg"),
    AndyPartDef(bodyPart: .leftLeg, scnSize: SCNVector3(0.5, 1.5, 0.5), position: SCNVector3(-0.25, 0.5, 0), name: "leftLeg"),
]

// MARK: - Non-Paintable Andy View

#if os(macOS)

private struct NonPaintableAndyView: NSViewRepresentable {
    let project: SkinProject
    var showGrid: Bool = false
    var activeBodyPart: SkinBodyPart = .head
    var activeFace: SkinFace = .front

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scnView.antialiasingMode = .none
        scnView.scene = Self.createScene(project: project, showGrid: showGrid, activeBodyPart: activeBodyPart, activeFace: activeFace)
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        for part in andyParts {
            if let node = scnView.scene?.rootNode.childNode(withName: part.name, recursively: true),
               let box = node.geometry as? SCNBox {
                box.materials = AndyPreviewView.materialsForPart(part.bodyPart, project: project, showGrid: showGrid, activeBodyPart: activeBodyPart, activeFace: activeFace)
                node.opacity = part.bodyPart == activeBodyPart ? 1.0 : 0.7
            }
        }
    }

    static func createScene(project: SkinProject, showGrid: Bool, activeBodyPart: SkinBodyPart = .head, activeFace: SkinFace = .front) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)

        for part in andyParts {
            let box = SCNBox(
                width: CGFloat(part.scnSize.x),
                height: CGFloat(part.scnSize.y),
                length: CGFloat(part.scnSize.z),
                chamferRadius: 0
            )
            box.materials = AndyPreviewView.materialsForPart(part.bodyPart, project: project, showGrid: showGrid, activeBodyPart: activeBodyPart, activeFace: activeFace)
            let node = SCNNode(geometry: box)
            node.name = part.name
            node.position = part.position
            node.opacity = part.bodyPart == activeBodyPart ? 1.0 : 0.7
            scene.rootNode.addChildNode(node)
        }

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 35
        cameraNode.position = SCNVector3(3.5, 2.5, 5.5)
        cameraNode.look(at: SCNVector3(0, 1.8, 0))
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)

        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.intensity = 500
        ambientNode.light?.color = NSColor.white
        scene.rootNode.addChildNode(ambientNode)

        let dirNode = SCNNode()
        dirNode.light = SCNLight()
        dirNode.light?.type = .directional
        dirNode.light?.intensity = 500
        dirNode.light?.color = NSColor.white
        dirNode.position = SCNVector3(3, 5, 3)
        dirNode.look(at: SCNVector3(0, 2, 0))
        scene.rootNode.addChildNode(dirNode)

        return scene
    }
}

#elseif os(iOS)

private struct NonPaintableAndyView: UIViewRepresentable {
    let project: SkinProject
    var showGrid: Bool = false
    var activeBodyPart: SkinBodyPart = .head
    var activeFace: SkinFace = .front

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scnView.antialiasingMode = .none
        scnView.scene = Self.createScene(project: project, showGrid: showGrid, activeBodyPart: activeBodyPart, activeFace: activeFace)
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        for part in andyParts {
            if let node = scnView.scene?.rootNode.childNode(withName: part.name, recursively: true),
               let box = node.geometry as? SCNBox {
                box.materials = AndyPreviewView.materialsForPart(part.bodyPart, project: project, showGrid: showGrid, activeBodyPart: activeBodyPart, activeFace: activeFace)
                node.opacity = part.bodyPart == activeBodyPart ? 1.0 : 0.7
            }
        }
    }

    static func createScene(project: SkinProject, showGrid: Bool, activeBodyPart: SkinBodyPart = .head, activeFace: SkinFace = .front) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)

        for part in andyParts {
            let box = SCNBox(
                width: CGFloat(part.scnSize.x),
                height: CGFloat(part.scnSize.y),
                length: CGFloat(part.scnSize.z),
                chamferRadius: 0
            )
            box.materials = AndyPreviewView.materialsForPart(part.bodyPart, project: project, showGrid: showGrid, activeBodyPart: activeBodyPart, activeFace: activeFace)
            let node = SCNNode(geometry: box)
            node.name = part.name
            node.position = part.position
            node.opacity = part.bodyPart == activeBodyPart ? 1.0 : 0.7
            scene.rootNode.addChildNode(node)
        }

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 35
        cameraNode.position = SCNVector3(3.5, 2.5, 5.5)
        cameraNode.look(at: SCNVector3(0, 1.8, 0))
        scene.rootNode.addChildNode(cameraNode)

        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.intensity = 500
        scene.rootNode.addChildNode(ambientNode)

        let dirNode = SCNNode()
        dirNode.light = SCNLight()
        dirNode.light?.type = .directional
        dirNode.light?.intensity = 500
        dirNode.position = SCNVector3(3, 5, 3)
        dirNode.look(at: SCNVector3(0, 2, 0))
        scene.rootNode.addChildNode(dirNode)

        return scene
    }
}

#endif
