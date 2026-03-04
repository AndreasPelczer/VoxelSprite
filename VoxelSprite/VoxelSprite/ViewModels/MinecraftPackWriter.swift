//
//  MinecraftPackWriter.swift
//  VoxelSprite
//
//  Erstellt Minecraft-Resourcepack und Datapack Verzeichnisstrukturen.
//  Zuständig für JSON-Generierung (Block Models, Blockstates, CTM, Pack Meta).
//

import Foundation

struct MinecraftPackWriter {

    let renderer: PNGRenderer

    // MARK: - Block Model JSON

    func createBlockModel(project: BlockProject, textureNames: [FaceType: String]) -> [String: Any] {
        let ns = project.namespace
        var textures: [String: String] = [:]

        if let allName = textureNames[.north], project.template == .fullBlock {
            textures["all"] = "\(ns):block/\(allName)"
        } else {
            for (faceType, name) in textureNames {
                let key: String
                switch faceType {
                case .top:    key = "top"
                case .bottom: key = "bottom"
                case .north:  key = "north"
                case .south:  key = "south"
                case .east:   key = "east"
                case .west:   key = "west"
                }
                textures[key] = "\(ns):block/\(name)"
            }
        }

        let parent: String
        switch project.template {
        case .fullBlock: parent = "minecraft:block/cube_all"
        default:         parent = "minecraft:block/cube"
        }

        return ["parent": parent, "textures": textures]
    }

    // MARK: - Blockstate JSON

    func createBlockstate(project: BlockProject) -> [String: Any] {
        let modelRef = "\(project.namespace):block/\(project.name)"

        switch project.rotation {
        case .none:
            return ["variants": ["": ["model": modelRef]]]
        case .directional:
            return ["variants": [
                "facing=north": ["model": modelRef],
                "facing=east":  ["model": modelRef, "y": 90],
                "facing=south": ["model": modelRef, "y": 180],
                "facing=west":  ["model": modelRef, "y": 270]
            ]]
        case .sixWay:
            return ["variants": [
                "facing=north": ["model": modelRef],
                "facing=east":  ["model": modelRef, "y": 90],
                "facing=south": ["model": modelRef, "y": 180],
                "facing=west":  ["model": modelRef, "y": 270],
                "facing=up":    ["model": modelRef, "x": 270],
                "facing=down":  ["model": modelRef, "x": 90]
            ]]
        case .random:
            return ["variants": ["": [
                ["model": modelRef],
                ["model": modelRef, "y": 90],
                ["model": modelRef, "y": 180],
                ["model": modelRef, "y": 270]
            ]]]
        }
    }

    // MARK: - Animation .mcmeta

    func createAnimationMcmeta(face: BlockFace) -> [String: Any] {
        var animation: [String: Any] = ["frametime": face.frameTime]
        if face.interpolate {
            animation["interpolate"] = true
        }
        return ["animation": animation]
    }

    // MARK: - CTM Export

    func exportCTMFiles(project: BlockProject, packDir: URL) throws {
        let fm = FileManager.default
        let ctmDir = packDir
            .appendingPathComponent("assets/\(project.namespace)/optifine/ctm/\(project.name)")
        try fm.createDirectory(at: ctmDir, withIntermediateDirectories: true)

        let primaryFaceType = determinePrimaryFace(project: project)
        let face = project.face(for: primaryFaceType)

        for (index, tileCanvas) in face.frames.enumerated() {
            guard let cgImage = renderer.renderCanvasToCGImage(tileCanvas, gridSize: project.gridSize) else {
                throw ExportError.frameRenderFailed
            }
            guard let pngData = renderer.cgImageToPNGData(cgImage) else {
                throw ExportError.pngEncodingFailed
            }
            try pngData.write(to: ctmDir.appendingPathComponent("\(index).png"), options: .atomic)
        }

        let properties = createCTMProperties(project: project, tileCount: face.frames.count)
        try properties.write(
            to: ctmDir.appendingPathComponent("\(project.name).properties"),
            atomically: true,
            encoding: .utf8
        )
    }

    func determinePrimaryFace(project: BlockProject) -> FaceType {
        switch project.template {
        case .fullBlock:  return .north
        case .grassStyle: return .north
        case .pillar:     return .north
        case .slab:       return .north
        case .custom:     return .north
        }
    }

    func createCTMProperties(project: BlockProject, tileCount: Int) -> String {
        var lines: [String] = []

        switch project.ctmMethod {
        case .none:
            return ""
        case .random:
            lines.append("method=random")
            if tileCount > 0 { lines.append("tiles=0-\(tileCount - 1)") }
        case .repeat_:
            lines.append("method=repeat")
            if tileCount > 0 { lines.append("tiles=0-\(tileCount - 1)") }
            lines.append("width=\(project.ctmRepeatWidth)")
            lines.append("height=\(project.ctmRepeatHeight)")
        }

        lines.append("matchBlocks=\(project.namespace):\(project.name)")
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Textur-Zuordnung

    func findUniqueTextures(project: BlockProject) -> [(FaceType, String)] {
        switch project.template {
        case .fullBlock:
            return [(.north, project.name)]
        case .grassStyle:
            return [
                (.top, "\(project.name)_top"),
                (.bottom, "\(project.name)_bottom"),
                (.north, "\(project.name)_side")
            ]
        case .pillar:
            return [
                (.top, "\(project.name)_top"),
                (.north, "\(project.name)_side")
            ]
        case .slab, .custom:
            return FaceType.allCases.map { ($0, "\(project.name)_\($0.rawValue.lowercased())") }
        }
    }

    func findTextureName(for faceType: FaceType, in uniqueTextures: [(FaceType, String)]) -> String {
        if let direct = uniqueTextures.first(where: { $0.0 == faceType }) {
            return direct.1
        }
        let sides: [FaceType] = [.north, .south, .east, .west]
        if sides.contains(faceType), let sideTexture = uniqueTextures.first(where: { sides.contains($0.0) }) {
            return sideTexture.1
        }
        return uniqueTextures.first?.1 ?? "unknown"
    }

    // MARK: - Item Model JSON

    func createItemModel(project: ItemProject) -> [String: Any] {
        var textures: [String: String] = [:]
        for index in 0..<project.layers.count {
            let texName = project.textureName(for: index)
            textures["layer\(index)"] = "\(project.namespace):item/\(texName)"
        }
        return ["parent": project.displayType.parent, "textures": textures]
    }

    // MARK: - Pack Meta

    func createPackMeta(description: String, version: BlockProject.TargetVersion) -> [String: Any] {
        let packFormat: Int
        switch version {
        case .java:    packFormat = 15
        case .bedrock: packFormat = 2
        }
        return ["pack": ["pack_format": packFormat, "description": description]]
    }

    func createDatapackMeta(description: String) -> [String: Any] {
        return ["pack": ["pack_format": 26, "description": description]]
    }
}
