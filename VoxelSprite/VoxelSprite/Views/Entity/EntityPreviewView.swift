//
//  EntityPreviewView.swift
//  VoxelSprite
//
//  3D-Vorschau für Minecraft-Entity-Mobs mit SceneKit.
//  Baut den Mob aus Box-Geometrien basierend auf EntityBodyPart-Definitionen.
//  Texturen werden aus dem Entity-Textur-Atlas per UV-Mapping extrahiert.
//  Unterstützt direktes Malen auf dem 3D-Modell.
//

import SwiftUI
import SceneKit

// MARK: - Entity Preview View

struct EntityPreviewView: View {

    @EnvironmentObject var entityVM: EntityViewModel
    @EnvironmentObject var canvasVM: CanvasViewModel

    /// Grid auf dem 3D-Modell anzeigen
    var showGrid: Bool = false

    /// Malen auf dem 3D-Modell aktivieren
    var paintEnabled: Bool = false

    @State private var scene: SCNScene = SCNScene()
    @State private var sceneReady = false
    @State private var currentEntityType: EntityType?
    @StateObject private var orbitState: OrbitCameraState = {
        let state = OrbitCameraState()
        state.azimuth = 0.5
        state.elevation = 0.4
        state.distance = 5.0
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
                EntityMobSceneView(project: entityVM.project, showGrid: showGrid)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
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
                currentEntityType = entityVM.project.entityType
            }
        }
        .onReceive(entityVM.objectWillChange) {
            guard paintEnabled else { return }
            // Bei Typ-Wechsel Scene neu aufbauen
            if entityVM.project.entityType != currentEntityType {
                rebuildScene()
                currentEntityType = entityVM.project.entityType
            } else {
                updateMaterials()
            }
        }
        .onChange(of: showGrid) { _ in
            if paintEnabled { updateMaterials() }
        }
    }

    // MARK: - Scene Setup

    private func setupScene() {
        buildScene(for: entityVM.project)
    }

    private func rebuildScene() {
        // Alle Nodes entfernen und neu aufbauen
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        buildScene(for: entityVM.project)
        // Kamera-Distanz an neuen Mob anpassen
        let cam = EntityMobLayout.cameraSetup(for: entityVM.project.entityType)
        orbitState.center = cam.lookAt
        let dx = cam.position.x - cam.lookAt.x
        let dy = cam.position.y - cam.lookAt.y
        let dz = cam.position.z - cam.lookAt.z
        orbitState.distance = sqrt(dx*dx + dy*dy + dz*dz)
        if let camNode = scene.rootNode.childNode(withName: "camera", recursively: true) {
            orbitState.updateCamera(camNode)
        }
    }

    private func buildScene(for project: EntityProject) {
        let bgColor: Any = {
            #if os(macOS)
            return NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
            #else
            return UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
            #endif
        }()
        scene.background.contents = bgColor
        scene.rootNode.name = project.entityType.rawValue

        let placements = EntityMobLayout.placements(for: project.entityType)
        for part in project.entityType.bodyParts {
            guard let placement = placements.first(where: { $0.partId == part.id }) else { continue }
            let w = CGFloat(part.boxW) / 8.0
            let h = CGFloat(part.boxH) / 8.0
            let d = CGFloat(part.boxD) / 8.0

            let box = SCNBox(width: w, height: h, length: d, chamferRadius: 0)
            box.materials = Self.materialsForPart(part, project: project, showGrid: showGrid)
            let node = SCNNode(geometry: box)
            node.name = part.id
            node.position = placement.position
            scene.rootNode.addChildNode(node)
        }

        let cam = EntityMobLayout.cameraSetup(for: project.entityType)
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 35
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)
        orbitState.center = cam.lookAt
        let dx = cam.position.x - cam.lookAt.x
        let dy = cam.position.y - cam.lookAt.y
        let dz = cam.position.z - cam.lookAt.z
        orbitState.distance = sqrt(dx*dx + dy*dy + dz*dz)
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
        dirNode.look(at: cam.lookAt)
        scene.rootNode.addChildNode(dirNode)
    }

    private func updateMaterials() {
        for part in entityVM.project.entityType.bodyParts {
            if let node = scene.rootNode.childNode(withName: part.id, recursively: true),
               let box = node.geometry as? SCNBox {
                box.materials = Self.materialsForPart(part, project: entityVM.project, showGrid: showGrid)
            }
        }
    }

    // MARK: - Paint Handling

    /// SCNBox Face-Index → SkinFace
    private static let boxFaceToSkinFace: [SkinFace] = [.right, .left, .top, .bottom, .front, .back]

    private func handlePaintHit(nodeName: String, faceIndex: Int, uv: CGPoint) {
        guard faceIndex >= 0, faceIndex < Self.boxFaceToSkinFace.count else { return }

        let bodyParts = entityVM.project.entityType.bodyParts
        guard let partIndex = bodyParts.firstIndex(where: { $0.id == nodeName }) else { return }

        let part = bodyParts[partIndex]
        let face = Self.boxFaceToSkinFace[faceIndex]

        // Zur richtigen Auswahl wechseln
        if entityVM.activePartIndex != partIndex {
            entityVM.selectPart(partIndex)
            canvasVM.resetUndoHistory()
        }
        if entityVM.activeFace != face {
            entityVM.selectFace(face)
            canvasVM.resetUndoHistory()
        }

        let canvas = entityVM.editCanvas

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

    static func materialsForPart(_ part: EntityBodyPart, project: EntityProject, showGrid: Bool) -> [SCNMaterial] {
        let faceOrder: [SkinFace] = [.right, .left, .top, .bottom, .front, .back]
        return faceOrder.map { face in
            let material = SCNMaterial()
            let canvas = project.extractRegion(bodyPart: part, face: face)
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

// MARK: - 3D-Positionierung pro Mob-Typ

struct EntityPartPlacement {
    let partId: String
    let position: SCNVector3
}

struct EntityMobLayout {

    static func placements(for type: EntityType) -> [EntityPartPlacement] {
        switch type {
        case .creeper:  return creeperLayout
        case .pig:      return pigLayout
        case .cow:      return cowLayout
        case .chicken:  return chickenLayout
        case .spider:   return spiderLayout
        case .enderman: return endermanLayout
        case .skeleton: return skeletonLayout
        }
    }

    static func cameraSetup(for type: EntityType) -> (position: SCNVector3, lookAt: SCNVector3) {
        switch type {
        case .creeper:  return (SCNVector3(3, 2.5, 4.5), SCNVector3(0, 1.5, 0))
        case .pig:      return (SCNVector3(3.5, 2, 5), SCNVector3(0, 1, 0))
        case .cow:      return (SCNVector3(4, 3, 6), SCNVector3(0, 1.5, 0))
        case .chicken:  return (SCNVector3(2.5, 1.5, 3.5), SCNVector3(0, 0.8, 0))
        case .spider:   return (SCNVector3(4, 2, 5), SCNVector3(0, 0.5, 0))
        case .enderman: return (SCNVector3(4, 3.5, 7), SCNVector3(0, 2.5, 0))
        case .skeleton: return (SCNVector3(3.5, 2.5, 5.5), SCNVector3(0, 1.5, 0))
        }
    }

    private static let creeperLayout: [EntityPartPlacement] = [
        EntityPartPlacement(partId: "head",   position: SCNVector3(0, 2.75, 0)),
        EntityPartPlacement(partId: "body",   position: SCNVector3(0, 1.5, 0)),
        EntityPartPlacement(partId: "leg_fr", position: SCNVector3(0.25, 0.375, 0.25)),
        EntityPartPlacement(partId: "leg_fl", position: SCNVector3(-0.25, 0.375, 0.25)),
        EntityPartPlacement(partId: "leg_br", position: SCNVector3(0.25, 0.375, -0.25)),
        EntityPartPlacement(partId: "leg_bl", position: SCNVector3(-0.25, 0.375, -0.25)),
    ]

    private static let pigLayout: [EntityPartPlacement] = [
        EntityPartPlacement(partId: "head",   position: SCNVector3(0, 1.25, 0.9375)),
        EntityPartPlacement(partId: "snout",  position: SCNVector3(0, 1.0, 1.5)),
        EntityPartPlacement(partId: "body",   position: SCNVector3(0, 1.25, 0)),
        EntityPartPlacement(partId: "leg_fr", position: SCNVector3(0.25, 0.375, 0.375)),
        EntityPartPlacement(partId: "leg_fl", position: SCNVector3(-0.25, 0.375, 0.375)),
        EntityPartPlacement(partId: "leg_br", position: SCNVector3(0.25, 0.375, -0.375)),
        EntityPartPlacement(partId: "leg_bl", position: SCNVector3(-0.25, 0.375, -0.375)),
    ]

    private static let cowLayout: [EntityPartPlacement] = [
        EntityPartPlacement(partId: "head",   position: SCNVector3(0, 2.0, 1.125)),
        EntityPartPlacement(partId: "horn_r", position: SCNVector3(0.5625, 2.6875, 1.125)),
        EntityPartPlacement(partId: "horn_l", position: SCNVector3(-0.5625, 2.6875, 1.125)),
        EntityPartPlacement(partId: "body",   position: SCNVector3(0, 1.875, 0)),
        EntityPartPlacement(partId: "leg_fr", position: SCNVector3(0.375, 0.75, 0.375)),
        EntityPartPlacement(partId: "leg_fl", position: SCNVector3(-0.375, 0.75, 0.375)),
        EntityPartPlacement(partId: "leg_br", position: SCNVector3(0.375, 0.75, -0.375)),
        EntityPartPlacement(partId: "leg_bl", position: SCNVector3(-0.375, 0.75, -0.375)),
    ]

    private static let chickenLayout: [EntityPartPlacement] = [
        EntityPartPlacement(partId: "head",   position: SCNVector3(0, 1.375, 0.375)),
        EntityPartPlacement(partId: "beak",   position: SCNVector3(0, 1.25, 0.6875)),
        EntityPartPlacement(partId: "wattle", position: SCNVector3(0, 1.0, 0.5)),
        EntityPartPlacement(partId: "body",   position: SCNVector3(0, 0.75, 0)),
        EntityPartPlacement(partId: "leg_r",  position: SCNVector3(0.125, 0.25, 0)),
        EntityPartPlacement(partId: "leg_l",  position: SCNVector3(-0.125, 0.25, 0)),
        EntityPartPlacement(partId: "wing_r", position: SCNVector3(0.4375, 0.75, 0)),
        EntityPartPlacement(partId: "wing_l", position: SCNVector3(-0.4375, 0.75, 0)),
    ]

    private static let spiderLayout: [EntityPartPlacement] = [
        EntityPartPlacement(partId: "head",    position: SCNVector3(0, 0.5, 1.125)),
        EntityPartPlacement(partId: "abdomen", position: SCNVector3(0, 0.5, -0.25)),
        EntityPartPlacement(partId: "thorax",  position: SCNVector3(0, 0.375, 0.625)),
    ]

    private static let endermanLayout: [EntityPartPlacement] = [
        EntityPartPlacement(partId: "head",      position: SCNVector3(0, 5.375, 0)),
        EntityPartPlacement(partId: "body",      position: SCNVector3(0, 3.375, 0)),
        EntityPartPlacement(partId: "right_arm", position: SCNVector3(0.375, 3.375, 0)),
        EntityPartPlacement(partId: "left_arm",  position: SCNVector3(-0.375, 3.375, 0)),
        EntityPartPlacement(partId: "right_leg", position: SCNVector3(0.125, 1.125, 0)),
        EntityPartPlacement(partId: "left_leg",  position: SCNVector3(-0.125, 1.125, 0)),
    ]

    private static let skeletonLayout: [EntityPartPlacement] = [
        EntityPartPlacement(partId: "head",      position: SCNVector3(0, 3.25, 0)),
        EntityPartPlacement(partId: "body",      position: SCNVector3(0, 2.0, 0)),
        EntityPartPlacement(partId: "right_arm", position: SCNVector3(0.625, 2.0, 0)),
        EntityPartPlacement(partId: "left_arm",  position: SCNVector3(-0.625, 2.0, 0)),
        EntityPartPlacement(partId: "right_leg", position: SCNVector3(0.125, 0.75, 0)),
        EntityPartPlacement(partId: "left_leg",  position: SCNVector3(-0.125, 0.75, 0)),
    ]
}

// MARK: - Non-Paintable Entity View

#if os(macOS)

struct EntityMobSceneView: NSViewRepresentable {
    let project: EntityProject
    var showGrid: Bool = false

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scnView.antialiasingMode = .none
        scnView.scene = Self.createScene(project: project, showGrid: showGrid)
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        let currentType = scnView.scene?.rootNode.name ?? ""
        if currentType != project.entityType.rawValue {
            scnView.scene = Self.createScene(project: project, showGrid: showGrid)
        } else {
            Self.updateMaterials(scene: scnView.scene, project: project, showGrid: showGrid)
        }
    }

    static func createScene(project: EntityProject, showGrid: Bool) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scene.rootNode.name = project.entityType.rawValue

        let placements = EntityMobLayout.placements(for: project.entityType)
        for part in project.entityType.bodyParts {
            guard let placement = placements.first(where: { $0.partId == part.id }) else { continue }
            let w = CGFloat(part.boxW) / 8.0
            let h = CGFloat(part.boxH) / 8.0
            let d = CGFloat(part.boxD) / 8.0
            let box = SCNBox(width: w, height: h, length: d, chamferRadius: 0)
            box.materials = EntityPreviewView.materialsForPart(part, project: project, showGrid: showGrid)
            let node = SCNNode(geometry: box)
            node.name = part.id
            node.position = placement.position
            scene.rootNode.addChildNode(node)
        }

        let cam = EntityMobLayout.cameraSetup(for: project.entityType)
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 35
        cameraNode.position = cam.position
        cameraNode.look(at: cam.lookAt)
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
        dirNode.look(at: cam.lookAt)
        scene.rootNode.addChildNode(dirNode)

        return scene
    }

    static func updateMaterials(scene: SCNScene?, project: EntityProject, showGrid: Bool) {
        guard let scene = scene else { return }
        for part in project.entityType.bodyParts {
            if let node = scene.rootNode.childNode(withName: part.id, recursively: true),
               let box = node.geometry as? SCNBox {
                box.materials = EntityPreviewView.materialsForPart(part, project: project, showGrid: showGrid)
            }
        }
    }
}

#elseif os(iOS)

struct EntityMobSceneView: UIViewRepresentable {
    let project: EntityProject
    var showGrid: Bool = false

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scnView.antialiasingMode = .none
        scnView.scene = Self.createScene(project: project, showGrid: showGrid)
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        let currentType = scnView.scene?.rootNode.name ?? ""
        if currentType != project.entityType.rawValue {
            scnView.scene = Self.createScene(project: project, showGrid: showGrid)
        } else {
            Self.updateMaterials(scene: scnView.scene, project: project, showGrid: showGrid)
        }
    }

    static func createScene(project: EntityProject, showGrid: Bool) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scene.rootNode.name = project.entityType.rawValue

        let placements = EntityMobLayout.placements(for: project.entityType)
        for part in project.entityType.bodyParts {
            guard let placement = placements.first(where: { $0.partId == part.id }) else { continue }
            let w = CGFloat(part.boxW) / 8.0
            let h = CGFloat(part.boxH) / 8.0
            let d = CGFloat(part.boxD) / 8.0
            let box = SCNBox(width: w, height: h, length: d, chamferRadius: 0)
            box.materials = EntityPreviewView.materialsForPart(part, project: project, showGrid: showGrid)
            let node = SCNNode(geometry: box)
            node.name = part.id
            node.position = placement.position
            scene.rootNode.addChildNode(node)
        }

        let cam = EntityMobLayout.cameraSetup(for: project.entityType)
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 35
        cameraNode.position = cam.position
        cameraNode.look(at: cam.lookAt)
        cameraNode.name = "camera"
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
        dirNode.look(at: cam.lookAt)
        scene.rootNode.addChildNode(dirNode)

        return scene
    }

    static func updateMaterials(scene: SCNScene?, project: EntityProject, showGrid: Bool) {
        guard let scene = scene else { return }
        for part in project.entityType.bodyParts {
            if let node = scene.rootNode.childNode(withName: part.id, recursively: true),
               let box = node.geometry as? SCNBox {
                box.materials = EntityPreviewView.materialsForPart(part, project: project, showGrid: showGrid)
            }
        }
    }
}

#endif
