//
//  StevePreviewView.swift
//  VoxelSprite
//
//  3D-Vorschau von Steve/Alex mit SceneKit.
//  Baut den Charakter aus 6 Box-Geometrien (Kopf, Körper, Arme, Beine).
//  Base + Overlay Layer werden als Texturen angewendet.
//

import SwiftUI
import SceneKit

struct StevePreviewView: View {

    @EnvironmentObject var skinVM: SkinViewModel

    private let previewSize: CGFloat = 200

    var body: some View {
        SteveSceneView(project: skinVM.project)
            .frame(width: previewSize, height: previewSize)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Steve Body Part Definition

private struct StevePartDef {
    let bodyPart: SkinBodyPart
    let scnSize: SCNVector3      // SceneKit Box Dimensions
    let position: SCNVector3     // Center position
    let name: String
}

/// Steve Proportionen (normalisiert: 1 Unit = 8 Pixel, Steve ~4 Units hoch)
private let steveParts: [StevePartDef] = [
    // Kopf: 8×8×8 → 1×1×1, Mitte bei y=3.5 (top=4, bottom=3)
    StevePartDef(bodyPart: .head, scnSize: SCNVector3(1, 1, 1), position: SCNVector3(0, 3.25, 0), name: "head"),
    // Körper: 8×12×4 → 1×1.5×0.5, Mitte bei y=2 (top=2.75, bottom=1.25)
    StevePartDef(bodyPart: .body, scnSize: SCNVector3(1, 1.5, 0.5), position: SCNVector3(0, 2, 0), name: "body"),
    // R. Arm: 4×12×4 → 0.5×1.5×0.5, rechts vom Körper
    StevePartDef(bodyPart: .rightArm, scnSize: SCNVector3(0.5, 1.5, 0.5), position: SCNVector3(0.75, 2, 0), name: "rightArm"),
    // L. Arm: 4×12×4 → 0.5×1.5×0.5, links vom Körper
    StevePartDef(bodyPart: .leftArm, scnSize: SCNVector3(0.5, 1.5, 0.5), position: SCNVector3(-0.75, 2, 0), name: "leftArm"),
    // R. Bein: 4×12×4 → 0.5×1.5×0.5, rechte Hälfte unten
    StevePartDef(bodyPart: .rightLeg, scnSize: SCNVector3(0.5, 1.5, 0.5), position: SCNVector3(0.25, 0.5, 0), name: "rightLeg"),
    // L. Bein: 4×12×4 → 0.5×1.5×0.5, linke Hälfte unten
    StevePartDef(bodyPart: .leftLeg, scnSize: SCNVector3(0.5, 1.5, 0.5), position: SCNVector3(-0.25, 0.5, 0), name: "leftLeg"),
]

// MARK: - Platform SCNView Wrapper

#if os(macOS)

struct SteveSceneView: NSViewRepresentable {
    let project: SkinProject

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scnView.antialiasingMode = .none
        scnView.scene = Self.createScene(project: project)
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        Self.updateMaterials(scene: scnView.scene, project: project)
    }

    static func createScene(project: SkinProject) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)

        // Steve Körperteile erstellen
        for part in steveParts {
            let box = SCNBox(
                width: CGFloat(part.scnSize.x),
                height: CGFloat(part.scnSize.y),
                length: CGFloat(part.scnSize.z),
                chamferRadius: 0
            )
            box.materials = Self.materialsForPart(part.bodyPart, project: project)

            let node = SCNNode(geometry: box)
            node.name = part.name
            node.position = part.position
            scene.rootNode.addChildNode(node)
        }

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 30
        cameraNode.position = SCNVector3(3, 2.5, 5)
        cameraNode.look(at: SCNVector3(0, 2, 0))
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)

        // Ambient Light
        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.intensity = 500
        ambientNode.light?.color = NSColor.white
        scene.rootNode.addChildNode(ambientNode)

        // Directional
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

    static func updateMaterials(scene: SCNScene?, project: SkinProject) {
        guard let scene = scene else { return }
        for part in steveParts {
            if let node = scene.rootNode.childNode(withName: part.name, recursively: true),
               let box = node.geometry as? SCNBox {
                box.materials = materialsForPart(part.bodyPart, project: project)
            }
        }
    }

    /// Erzeugt 6 Materials für ein Körperteil.
    /// SCNBox Reihenfolge: +X(Right), -X(Left), +Y(Top), -Y(Bottom), +Z(Front), -Z(Back)
    static func materialsForPart(_ bodyPart: SkinBodyPart, project: SkinProject) -> [SCNMaterial] {
        // SCNBox face order: +X, -X, +Y, -Y, +Z, -Z
        // Mapped to SkinFace: right, left, top, bottom, front, back
        let faceOrder: [SkinFace] = [.right, .left, .top, .bottom, .front, .back]

        return faceOrder.map { face in
            let material = SCNMaterial()

            // Base Layer Textur
            let baseCanvas = project.extractRegion(bodyPart: bodyPart, face: face, layer: .base)
            if let baseImage = baseCanvas.toCGImage() {
                // Compositing: Base + Overlay
                let overlayCanvas = project.extractRegion(bodyPart: bodyPart, face: face, layer: .overlay)
                if let overlayImage = overlayCanvas.toCGImage() {
                    // Composite both layers
                    let composited = compositeImages(base: baseImage, overlay: overlayImage,
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
            return material
        }
    }

    /// Compositet zwei CGImages (Base + Overlay)
    static func compositeImages(base: CGImage, overlay: CGImage, width: Int, height: Int) -> CGImage? {
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        ctx.draw(base, in: rect)
        ctx.draw(overlay, in: rect)
        return ctx.makeImage()
    }
}

#elseif os(iOS)

struct SteveSceneView: UIViewRepresentable {
    let project: SkinProject

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scnView.antialiasingMode = .none
        scnView.scene = Self.createScene(project: project)
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        Self.updateMaterials(scene: scnView.scene, project: project)
    }

    static func createScene(project: SkinProject) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)

        for part in steveParts {
            let box = SCNBox(
                width: CGFloat(part.scnSize.x),
                height: CGFloat(part.scnSize.y),
                length: CGFloat(part.scnSize.z),
                chamferRadius: 0
            )
            box.materials = Self.materialsForPart(part.bodyPart, project: project)
            let node = SCNNode(geometry: box)
            node.name = part.name
            node.position = part.position
            scene.rootNode.addChildNode(node)
        }

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 30
        cameraNode.position = SCNVector3(3, 2.5, 5)
        cameraNode.look(at: SCNVector3(0, 2, 0))
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

    static func updateMaterials(scene: SCNScene?, project: SkinProject) {
        guard let scene = scene else { return }
        for part in steveParts {
            if let node = scene.rootNode.childNode(withName: part.name, recursively: true),
               let box = node.geometry as? SCNBox {
                box.materials = materialsForPart(part.bodyPart, project: project)
            }
        }
    }

    static func materialsForPart(_ bodyPart: SkinBodyPart, project: SkinProject) -> [SCNMaterial] {
        let faceOrder: [SkinFace] = [.right, .left, .top, .bottom, .front, .back]
        return faceOrder.map { face in
            let material = SCNMaterial()
            let baseCanvas = project.extractRegion(bodyPart: bodyPart, face: face, layer: .base)
            if let baseImage = baseCanvas.toCGImage() {
                material.diffuse.contents = baseImage
            }
            material.diffuse.magnificationFilter = .nearest
            material.diffuse.minificationFilter = .nearest
            material.lightingModel = .blinn
            return material
        }
    }
}

#endif
