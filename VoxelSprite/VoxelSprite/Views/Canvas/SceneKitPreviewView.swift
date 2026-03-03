//
//  SceneKitPreviewView.swift
//  VoxelSprite
//
//  Echter 3D-Würfel mit SceneKit.
//  Zeigt alle 6 Face-Texturen auf einem drehbaren Würfel.
//  Pixel-Art bleibt scharf durch Nearest-Neighbor-Filtering.
//  Optional: Pixel-Grid-Overlay auf dem Modell.
//

import SwiftUI
import SceneKit

// MARK: - Block Cube Preview

struct SceneKitPreviewView: View {

    @EnvironmentObject var blockVM: BlockViewModel

    /// Grid auf dem 3D-Modell anzeigen
    var showGrid: Bool = false

    var body: some View {
        BlockCubeSceneView(project: blockVM.project, showGrid: showGrid)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Platform-specific SCNView Wrapper

#if os(macOS)

struct BlockCubeSceneView: NSViewRepresentable {
    let project: BlockProject
    var showGrid: Bool = false

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
        box.materials = Self.createMaterials(project: project, showGrid: showGrid)
    }

    static func createScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)

        // Cube
        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        let cubeNode = SCNNode(geometry: box)
        cubeNode.name = "cube"
        scene.rootNode.addChildNode(cubeNode)

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 35
        cameraNode.position = SCNVector3(1.8, 1.4, 1.8)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)

        // Ambient Light
        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.intensity = 400
        ambientNode.light?.color = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
        scene.rootNode.addChildNode(ambientNode)

        // Directional Light
        let directionalNode = SCNNode()
        directionalNode.light = SCNLight()
        directionalNode.light?.type = .directional
        directionalNode.light?.intensity = 600
        directionalNode.light?.color = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
        directionalNode.position = SCNVector3(2, 4, 2)
        directionalNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalNode)

        return scene
    }

    /// Erzeugt 6 Materials für die Würfelflächen.
    /// SCNBox Reihenfolge: +X(East), -X(West), +Y(Top), -Y(Bottom), +Z(North), -Z(South)
    static func createMaterials(project: BlockProject, showGrid: Bool) -> [SCNMaterial] {
        let faceOrder: [FaceType] = [.east, .west, .top, .bottom, .north, .south]
        return faceOrder.map { faceType in
            let material = SCNMaterial()
            let canvas = project.canvas(for: faceType)
            if let image = canvas.toCGImage(showGrid: showGrid) {
                material.diffuse.contents = image
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

#elseif os(iOS)

struct BlockCubeSceneView: UIViewRepresentable {
    let project: BlockProject
    var showGrid: Bool = false

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
        box.materials = Self.createMaterials(project: project, showGrid: showGrid)
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

    static func createMaterials(project: BlockProject, showGrid: Bool) -> [SCNMaterial] {
        let faceOrder: [FaceType] = [.east, .west, .top, .bottom, .north, .south]
        return faceOrder.map { faceType in
            let material = SCNMaterial()
            let canvas = project.canvas(for: faceType)
            if let image = canvas.toCGImage(showGrid: showGrid) {
                material.diffuse.contents = image
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

#endif
