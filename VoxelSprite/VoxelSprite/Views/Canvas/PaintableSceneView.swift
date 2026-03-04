//
//  PaintableSceneView.swift
//  VoxelSprite
//
//  Shared 3D SceneKit-View die sowohl Kamera-Rotation als auch
//  direktes Malen auf dem 3D-Modell unterstützt.
//
//  Interaktion:
//    iOS:   1 Finger = Malen, 2 Finger = Drehen/Zoomen
//    macOS: Klick = Malen, Rechtsklick/Option+Drag = Drehen, Scroll = Zoom
//

import SwiftUI
import SceneKit

// MARK: - Paint Callback

/// Callback wenn ein Pixel auf dem 3D-Modell gemalt wird.
/// `nodeName`: Name des getroffenen Nodes (z.B. "cube", "head", "body")
/// `faceIndex`: SCNBox-Face-Index (0=+X, 1=-X, 2=+Y, 3=-Y, 4=+Z, 5=-Z)
/// `uv`: Textur-Koordinaten (0…1)
typealias PaintHitCallback = (_ nodeName: String, _ faceIndex: Int, _ uv: CGPoint) -> Void

// MARK: - Orbit Camera State

/// Orbit-Kamera die um ein Zentrum rotiert.
class OrbitCameraState: ObservableObject {
    var azimuth: Float = 0.3       // Horizontal-Rotation in Radians
    var elevation: Float = 0.3     // Vertikal-Rotation in Radians
    var distance: Float = 5.0      // Distanz zum Zentrum
    var center: SCNVector3 = SCNVector3(0, 0, 0)

    func position() -> SCNVector3 {
        let clampedElev = max(-Float.pi / 2 + 0.01, min(Float.pi / 2 - 0.01, elevation))
        let x = center.x + distance * cos(clampedElev) * sin(azimuth)
        let y = center.y + distance * sin(clampedElev)
        let z = center.z + distance * cos(clampedElev) * cos(azimuth)
        return SCNVector3(x, y, z)
    }

    func updateCamera(_ cameraNode: SCNNode) {
        cameraNode.position = position()
        cameraNode.look(at: center)
    }
}

// MARK: - macOS Implementation

#if os(macOS)

struct PaintableSceneView: NSViewRepresentable {

    let scene: SCNScene
    var onPaintHit: PaintHitCallback?
    var onPaintEnd: (() -> Void)?
    let orbitState: OrbitCameraState

    func makeCoordinator() -> Coordinator {
        Coordinator(onPaintHit: onPaintHit, onPaintEnd: onPaintEnd, orbitState: orbitState)
    }

    func makeNSView(context: Context) -> SCNView {
        let scnView = PaintableSCNView()
        scnView.orbitState = orbitState
        scnView.allowsCameraControl = false // Wir machen es selbst
        scnView.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scnView.antialiasingMode = .none
        scnView.scene = scene

        context.coordinator.scnView = scnView

        // Camera initialisieren
        if let cam = scene.rootNode.childNode(withName: "camera", recursively: true) {
            orbitState.updateCamera(cam)
        }

        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        context.coordinator.onPaintHit = onPaintHit
        context.coordinator.onPaintEnd = onPaintEnd
        if scnView.scene !== scene {
            scnView.scene = scene
            if let cam = scene.rootNode.childNode(withName: "camera", recursively: true) {
                orbitState.updateCamera(cam)
            }
        }
    }

    class Coordinator: NSObject {
        var onPaintHit: PaintHitCallback?
        var onPaintEnd: (() -> Void)?
        let orbitState: OrbitCameraState
        weak var scnView: SCNView? {
            didSet { setupGestures() }
        }
        private var isPainting = false
        private var lastDragPoint: NSPoint = .zero

        init(onPaintHit: PaintHitCallback?, onPaintEnd: (() -> Void)?, orbitState: OrbitCameraState) {
            self.onPaintHit = onPaintHit
            self.onPaintEnd = onPaintEnd
            self.orbitState = orbitState
            super.init()
        }

        private func setupGestures() {
            guard let scnView = scnView else { return }

            // Linksklick: Malen
            let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
            clickGesture.buttonMask = 0x1
            scnView.addGestureRecognizer(clickGesture)

            // Drag: Malen (links) oder Drehen (rechts/Option)
            let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            scnView.addGestureRecognizer(panGesture)

            // Scroll: Zoom
            // Scroll-Events kommen über scrollWheel auf SCNView
            // Wir brauchen eine Subclass oder Monitor
            let magnifyGesture = NSMagnificationGestureRecognizer(target: self, action: #selector(handleMagnify(_:)))
            scnView.addGestureRecognizer(magnifyGesture)

            // Rechtsklick-Drag für Rotation
            let rightPan = NSPanGestureRecognizer(target: self, action: #selector(handleRightPan(_:)))
            rightPan.buttonMask = 0x2
            scnView.addGestureRecognizer(rightPan)
        }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let scnView = scnView else { return }
            let location = gesture.location(in: scnView)
            performPaintHit(at: location)
            onPaintEnd?()
        }

        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            guard let scnView = scnView else { return }

            let modifiers = NSEvent.modifierFlags
            let isRotate = modifiers.contains(.option)

            if isRotate {
                // Option+Drag = Drehen
                let delta = gesture.translation(in: scnView)
                orbitState.azimuth -= Float(delta.x) * 0.01
                orbitState.elevation += Float(delta.y) * 0.01
                orbitState.elevation = max(-Float.pi / 2 + 0.1, min(Float.pi / 2 - 0.1, orbitState.elevation))
                if let cam = scnView.scene?.rootNode.childNode(withName: "camera", recursively: true) {
                    orbitState.updateCamera(cam)
                }
                gesture.setTranslation(.zero, in: scnView)
            } else {
                // Normaler Drag = Malen
                let location = gesture.location(in: scnView)
                switch gesture.state {
                case .began:
                    isPainting = true
                    performPaintHit(at: location)
                case .changed:
                    if isPainting { performPaintHit(at: location) }
                case .ended, .cancelled:
                    if isPainting { onPaintEnd?() }
                    isPainting = false
                default: break
                }
            }
        }

        @objc func handleRightPan(_ gesture: NSPanGestureRecognizer) {
            guard let scnView = scnView else { return }
            let delta = gesture.translation(in: scnView)
            orbitState.azimuth -= Float(delta.x) * 0.01
            orbitState.elevation += Float(delta.y) * 0.01
            orbitState.elevation = max(-Float.pi / 2 + 0.1, min(Float.pi / 2 - 0.1, orbitState.elevation))
            if let cam = scnView.scene?.rootNode.childNode(withName: "camera", recursively: true) {
                orbitState.updateCamera(cam)
            }
            gesture.setTranslation(.zero, in: scnView)
        }

        @objc func handleMagnify(_ gesture: NSMagnificationGestureRecognizer) {
            guard let scnView = scnView else { return }
            orbitState.distance *= 1.0 - Float(gesture.magnification) * 0.5
            orbitState.distance = max(1.0, min(20.0, orbitState.distance))
            gesture.magnification = 0
            if let cam = scnView.scene?.rootNode.childNode(withName: "camera", recursively: true) {
                orbitState.updateCamera(cam)
            }
        }

        private func performPaintHit(at point: NSPoint) {
            guard let scnView = scnView, let onPaintHit = onPaintHit else { return }
            let results = scnView.hitTest(point, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue,
                .ignoreHiddenNodes: true
            ])
            guard let hit = results.first,
                  let nodeName = hit.node.name else { return }

            let faceIndex = hit.faceIndex
            let uv = hit.textureCoordinates(withMappingChannel: 0)

            // SCNBox hat 2 Dreiecke pro Face → faceIndex / 2 = Face-Nummer
            let boxFace = faceIndex / 2

            onPaintHit(nodeName, boxFace, uv)
        }
    }
}

// MARK: - Scroll Wheel Support (macOS)

/// SCNView-Subclass die Scroll-Events für Zoom abfängt
class PaintableSCNView: SCNView {
    var orbitState: OrbitCameraState?

    override func scrollWheel(with event: NSEvent) {
        guard let orbitState = orbitState else {
            super.scrollWheel(with: event)
            return
        }
        let delta = Float(event.scrollingDeltaY) * 0.05
        orbitState.distance *= (1.0 - delta)
        orbitState.distance = max(1.0, min(20.0, orbitState.distance))
        if let cam = scene?.rootNode.childNode(withName: "camera", recursively: true) {
            orbitState.updateCamera(cam)
        }
    }
}

#elseif os(iOS)

struct PaintableSceneView: UIViewRepresentable {

    let scene: SCNScene
    var onPaintHit: PaintHitCallback?
    var onPaintEnd: (() -> Void)?
    let orbitState: OrbitCameraState

    func makeCoordinator() -> Coordinator {
        Coordinator(onPaintHit: onPaintHit, onPaintEnd: onPaintEnd, orbitState: orbitState)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = false
        scnView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scnView.antialiasingMode = .none
        scnView.scene = scene
        scnView.isMultipleTouchEnabled = true

        context.coordinator.scnView = scnView
        context.coordinator.setupGestures()

        if let cam = scene.rootNode.childNode(withName: "camera", recursively: true) {
            orbitState.updateCamera(cam)
        }

        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        context.coordinator.onPaintHit = onPaintHit
        context.coordinator.onPaintEnd = onPaintEnd
        if scnView.scene !== scene {
            scnView.scene = scene
            if let cam = scene.rootNode.childNode(withName: "camera", recursively: true) {
                orbitState.updateCamera(cam)
            }
        }
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPaintHit: PaintHitCallback?
        var onPaintEnd: (() -> Void)?
        let orbitState: OrbitCameraState
        weak var scnView: SCNView?
        private var isPainting = false

        init(onPaintHit: PaintHitCallback?, onPaintEnd: (() -> Void)?, orbitState: OrbitCameraState) {
            self.onPaintHit = onPaintHit
            self.onPaintEnd = onPaintEnd
            self.orbitState = orbitState
            super.init()
        }

        func setupGestures() {
            guard let scnView = scnView else { return }

            // 1-Finger Pan = Malen
            let paintPan = UIPanGestureRecognizer(target: self, action: #selector(handlePaintPan(_:)))
            paintPan.maximumNumberOfTouches = 1
            paintPan.delegate = self
            scnView.addGestureRecognizer(paintPan)

            // 1-Finger Tap = Einzel-Pixel
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.numberOfTouchesRequired = 1
            scnView.addGestureRecognizer(tap)

            // 2-Finger Pan = Drehen
            let rotatePan = UIPanGestureRecognizer(target: self, action: #selector(handleRotatePan(_:)))
            rotatePan.minimumNumberOfTouches = 2
            rotatePan.maximumNumberOfTouches = 2
            rotatePan.delegate = self
            scnView.addGestureRecognizer(rotatePan)

            // Pinch = Zoom
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self
            scnView.addGestureRecognizer(pinch)
        }

        // Erlaube simultane Erkennung für Rotate + Pinch
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Rotate + Pinch gleichzeitig erlauben
            let isRotateOrPinch = gestureRecognizer is UIPinchGestureRecognizer ||
                                  (gestureRecognizer is UIPanGestureRecognizer &&
                                   (gestureRecognizer as! UIPanGestureRecognizer).minimumNumberOfTouches == 2)
            let otherIsRotateOrPinch = otherGestureRecognizer is UIPinchGestureRecognizer ||
                                       (otherGestureRecognizer is UIPanGestureRecognizer &&
                                        (otherGestureRecognizer as! UIPanGestureRecognizer).minimumNumberOfTouches == 2)
            return isRotateOrPinch && otherIsRotateOrPinch
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = scnView else { return }
            let location = gesture.location(in: scnView)
            performPaintHit(at: location)
            onPaintEnd?()
        }

        @objc func handlePaintPan(_ gesture: UIPanGestureRecognizer) {
            guard let scnView = scnView else { return }
            let location = gesture.location(in: scnView)

            switch gesture.state {
            case .began:
                isPainting = true
                performPaintHit(at: location)
            case .changed:
                if isPainting { performPaintHit(at: location) }
            case .ended, .cancelled:
                if isPainting { onPaintEnd?() }
                isPainting = false
            default: break
            }
        }

        @objc func handleRotatePan(_ gesture: UIPanGestureRecognizer) {
            guard let scnView = scnView else { return }
            let delta = gesture.translation(in: scnView)
            orbitState.azimuth -= Float(delta.x) * 0.01
            orbitState.elevation -= Float(delta.y) * 0.01
            orbitState.elevation = max(-Float.pi / 2 + 0.1, min(Float.pi / 2 - 0.1, orbitState.elevation))
            if let cam = scnView.scene?.rootNode.childNode(withName: "camera", recursively: true) {
                orbitState.updateCamera(cam)
            }
            gesture.setTranslation(.zero, in: scnView)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let scnView = scnView else { return }
            orbitState.distance /= Float(gesture.scale)
            orbitState.distance = max(1.0, min(20.0, orbitState.distance))
            gesture.scale = 1.0
            if let cam = scnView.scene?.rootNode.childNode(withName: "camera", recursively: true) {
                orbitState.updateCamera(cam)
            }
        }

        private func performPaintHit(at point: CGPoint) {
            guard let scnView = scnView, let onPaintHit = onPaintHit else { return }
            let results = scnView.hitTest(point, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue,
                .ignoreHiddenNodes: true
            ])
            guard let hit = results.first,
                  let nodeName = hit.node.name else { return }

            let faceIndex = hit.faceIndex
            let uv = hit.textureCoordinates(withMappingChannel: 0)
            let boxFace = faceIndex / 2

            onPaintHit(nodeName, boxFace, uv)
        }
    }
}

#endif
