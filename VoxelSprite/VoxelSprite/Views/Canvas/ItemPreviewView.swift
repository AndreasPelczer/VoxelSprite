//
//  ItemPreviewView.swift
//  VoxelSprite
//
//  3D-Vorschau für Items.
//  Zeigt das Item als flaches Sprite auf einer SCNPlane.
//  Pixel-Art bleibt scharf durch Nearest-Neighbor-Filtering.
//  Unterstützt Generated (flach) und Handheld (Tool-Winkel) Display.
//

import SwiftUI
import SceneKit

// MARK: - Item Preview

struct ItemPreviewView: View {

    @EnvironmentObject var itemVM: ItemViewModel

    /// Grid auf dem 3D-Modell anzeigen
    var showGrid: Bool = false

    var body: some View {
        ItemSpriteSceneView(project: itemVM.project, showGrid: showGrid)
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

struct ItemSpriteSceneView: NSViewRepresentable {
    let project: ItemProject
    var showGrid: Bool = false

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scnView.antialiasingMode = .none
        scnView.scene = Self.createScene(displayType: project.displayType)
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        guard let itemNode = scnView.scene?.rootNode.childNode(withName: "item", recursively: true),
              let plane = itemNode.geometry as? SCNPlane else { return }
        Self.updateMaterial(plane: plane, project: project, showGrid: showGrid)
    }

    static func createScene(displayType: ItemDisplayType) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)

        // Item Plane (doppelseitig)
        let plane = SCNPlane(width: 1, height: 1)
        let itemNode = SCNNode(geometry: plane)
        itemNode.name = "item"

        // Winkel je nach Display-Typ
        switch displayType {
        case .generated:
            // Leicht geneigt wie im Inventar
            itemNode.eulerAngles = SCNVector3(-0.15, 0.4, 0)
        case .handheld:
            // Tool-Winkel (wie in der Hand gehalten)
            itemNode.eulerAngles = SCNVector3(0, 0.4, -0.78)
        }

        scene.rootNode.addChildNode(itemNode)

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 30
        cameraNode.position = SCNVector3(0, 0.1, 2.0)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)

        // Ambient Light
        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.intensity = 600
        ambientNode.light?.color = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
        scene.rootNode.addChildNode(ambientNode)

        // Directional Light
        let directionalNode = SCNNode()
        directionalNode.light = SCNLight()
        directionalNode.light?.type = .directional
        directionalNode.light?.intensity = 500
        directionalNode.light?.color = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
        directionalNode.position = SCNVector3(1, 3, 2)
        directionalNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalNode)

        return scene
    }

    static func updateMaterial(plane: SCNPlane, project: ItemProject, showGrid: Bool) {
        let composited = project.composited()
        guard let cgImage = composited.toCGImage(showGrid: showGrid) else { return }

        let material = SCNMaterial()
        material.diffuse.contents = cgImage
        material.diffuse.magnificationFilter = .nearest
        material.diffuse.minificationFilter = .nearest
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        material.lightingModel = .constant // Flach beleuchtet für 2D-Look
        material.isDoubleSided = true
        material.transparencyMode = .aOne

        plane.materials = [material]
    }
}

#elseif os(iOS)

struct ItemSpriteSceneView: UIViewRepresentable {
    let project: ItemProject
    var showGrid: Bool = false

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scnView.antialiasingMode = .none
        scnView.scene = Self.createScene(displayType: project.displayType)
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        guard let itemNode = scnView.scene?.rootNode.childNode(withName: "item", recursively: true),
              let plane = itemNode.geometry as? SCNPlane else { return }
        Self.updateMaterial(plane: plane, project: project, showGrid: showGrid)
    }

    static func createScene(displayType: ItemDisplayType) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)

        let plane = SCNPlane(width: 1, height: 1)
        let itemNode = SCNNode(geometry: plane)
        itemNode.name = "item"

        switch displayType {
        case .generated:
            itemNode.eulerAngles = SCNVector3(-0.15, 0.4, 0)
        case .handheld:
            itemNode.eulerAngles = SCNVector3(0, 0.4, -0.78)
        }

        scene.rootNode.addChildNode(itemNode)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 30
        cameraNode.position = SCNVector3(0, 0.1, 2.0)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)

        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.intensity = 600
        scene.rootNode.addChildNode(ambientNode)

        let directionalNode = SCNNode()
        directionalNode.light = SCNLight()
        directionalNode.light?.type = .directional
        directionalNode.light?.intensity = 500
        directionalNode.position = SCNVector3(1, 3, 2)
        directionalNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalNode)

        return scene
    }

    static func updateMaterial(plane: SCNPlane, project: ItemProject, showGrid: Bool) {
        let composited = project.composited()
        guard let cgImage = composited.toCGImage(showGrid: showGrid) else { return }

        let material = SCNMaterial()
        material.diffuse.contents = cgImage
        material.diffuse.magnificationFilter = .nearest
        material.diffuse.minificationFilter = .nearest
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.transparencyMode = .aOne

        plane.materials = [material]
    }
}

#endif
