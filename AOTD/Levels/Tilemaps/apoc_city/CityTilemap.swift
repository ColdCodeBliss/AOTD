//
//  CityTilemap.swift
//  AOTD
//

import SpriteKit
import UIKit

// JSON payload model (matches the file you added)
struct TileMapPayload: Decodable {
    struct Size: Decodable { let cols: Int?; let rows: Int?; let width: Int?; let height: Int? }
    struct Layer: Decodable { let name: String; let data: [[Int]] }
    let mapSize: Size
    let tileSize: Size
    let layers: [Layer]
}

/// Utility for loading/attaching the city collision tilemap behind the terrain.
struct CityTilemap: LevelTilemap {
    
    static let key = "apoc_city"
    /// Name used to find/remove/layout the map node in the scene.
    static let nodeName = "cityTilemap"

    /// Load the JSON, build a minimal tileset (walkable/obstacle), create the map,
    /// attach static physics to obstacle tiles, and insert it into the scene just above
    /// the terrain background.
    @discardableResult
    static func attach(to scene: (SKScene & SafeFrameProviding), below terrainNode: SKNode?) -> SKTileMapNode? {
        guard let map = try? loadMap() else { return nil }

        // Place and scale to fill the FULL SCENE (not just safe frame)
        layout(map: map, in: scene)

        // Ensure z-order: above terrain background but below gameplay
        let zBelow = (terrainNode?.zPosition ?? -1000)
        map.zPosition = zBelow + 1
        map.name = nodeName

        // Remove any previous instance
        scene.childNode(withName: nodeName)?.removeFromParent()
        scene.addChild(map)
        return map
    }

    /// Re-layout the existing tilemap when size changes.
    static func layout(in scene: (SKScene & SafeFrameProviding)) {
        guard let map = scene.childNode(withName: nodeName) as? SKTileMapNode else { return }
        layout(map: map, in: scene)
    }

    /// Remove the tilemap if present (e.g., when swapping terrains).
    static func remove(from scene: SKScene) {
        scene.childNode(withName: nodeName)?.removeFromParent()
    }

    // MARK: - Internals

    private static func loadMap() throws -> SKTileMapNode {
        // 1) Load JSON
        let url = Bundle.main.url(forResource: "tilemap_apoc_city_6px_tiles_collision", withExtension: "json")!
        let payload = try JSONDecoder().decode(TileMapPayload.self, from: Data(contentsOf: url))
        let cols = payload.mapSize.cols!
        let rows = payload.mapSize.rows!
        let tsW = CGFloat(payload.tileSize.width!)
        let tsH = CGFloat(payload.tileSize.height!)
        let tileSize = CGSize(width: tsW, height: tsH)

        // 2) Minimal tileset with two groups
        let walkDef = SKTileDefinition(texture: solidTexture(color: .clear, size: tileSize), size: tileSize)
        let obsDef  = SKTileDefinition(texture: solidTexture(color: UIColor.white.withAlphaComponent(0.001), size: tileSize), size: tileSize)

        let walkRule = SKTileGroupRule(adjacency: .adjacencyAll, tileDefinitions: [walkDef])
        let obsRule  = SKTileGroupRule(adjacency: .adjacencyAll, tileDefinitions: [obsDef])

        let walkGroup = SKTileGroup(rules: [walkRule]); walkGroup.name = "walkable"
        let obsGroup  = SKTileGroup(rules: [obsRule]);  obsGroup.name  = "obstacle"

        let tileSet = SKTileSet(tileGroups: [walkGroup, obsGroup], tileSetType: .grid)

        // 3) Build map
        let map = SKTileMapNode(tileSet: tileSet, columns: cols, rows: rows, tileSize: tileSize)

        // 4) Fill from collision layer and attach static physics for obstacles
        guard let grid = payload.layers.first(where: { $0.name.lowercased() == "collision" })?.data else {
            return map
        }
        for r in 0..<rows {
            for c in 0..<cols {
                let value = grid[r][c]
                let group = (value == 1) ? obsGroup : walkGroup
                // SpriteKit’s (0,0) is bottom-left; JSON is row-major top-down, so flip row.
                let rr = rows - 1 - r
                map.setTileGroup(group, forColumn: c, row: rr)

                if group === obsGroup {
                    let tileNode = SKNode()
                    tileNode.position = map.centerOfTile(atColumn: c, row: rr)
                    tileNode.physicsBody = SKPhysicsBody(rectangleOf: tileSize)
                    tileNode.physicsBody?.isDynamic = false
                    // Category bit mask for obstacles (tune as needed)
                    tileNode.physicsBody?.categoryBitMask = 0x1 << 1
                    tileNode.physicsBody?.collisionBitMask = 0xFFFFFFFF
                    tileNode.physicsBody?.contactTestBitMask = 0
                    map.addChild(tileNode)
                }
            }
        }
        return map
    }

    /// Aspect-fill to the **entire scene size** and center.
    private static func layout(map: SKTileMapNode, in scene: (SKScene & SafeFrameProviding)) {
        let sceneW = scene.size.width
        let sceneH = scene.size.height

        let rawW = CGFloat(map.numberOfColumns) * map.tileSize.width
        let rawH = CGFloat(map.numberOfRows)   * map.tileSize.height
        guard rawW > 0, rawH > 0 else { return }

        let scale = max(sceneW / rawW, sceneH / rawH)
        map.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        map.position = CGPoint(x: sceneW * 0.5, y: sceneH * 0.5)
        map.xScale = scale
        map.yScale = scale
    }

    private static func solidTexture(color: UIColor, size: CGSize) -> SKTexture {
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return SKTexture(image: img)
    }
}

// MARK: - Collision queries (grid hit-test)

extension CityTilemap {
    /// Returns the city tilemap node if present.
    static func currentMap(in scene: SKScene) -> SKTileMapNode? {
        scene.childNode(withName: CityTilemap.nodeName) as? SKTileMapNode
    }

    /// Convert a world-space point to (column,row) in the current map.
    /// Works with the centered, full-scene aspect-fill layout above.
    static func worldToTile(_ p: CGPoint, in scene: (SKScene & SafeFrameProviding)) -> (c: Int, r: Int)? {
        guard let map = currentMap(in: scene) else { return nil }

        // Undo scale & translation (map is centered with anchor 0.5,0.5)
        let localX = (p.x - map.position.x) / map.xScale
        let localY = (p.y - map.position.y) / map.yScale

        let mapW = CGFloat(map.numberOfColumns) * map.tileSize.width
        let mapH = CGFloat(map.numberOfRows)   * map.tileSize.height

        // Shift to bottom-left origin in local space
        let xBL = localX + mapW * 0.5
        let yBL = localY + mapH * 0.5

        let c = Int(xBL / map.tileSize.width)
        let rIdx = Int(yBL / map.tileSize.height)

        guard c >= 0, rIdx >= 0, c < map.numberOfColumns, rIdx < map.numberOfRows else { return nil }
        return (c, rIdx)
    }

    /// True if the world-space point lands on an obstacle tile.
    static func isBlocked(_ p: CGPoint, in scene: (SKScene & SafeFrameProviding)) -> Bool {
        guard let map = currentMap(in: scene),
              let (c, r) = worldToTile(p, in: scene) else { return false }
        return map.tileGroup(atColumn: c, row: r)?.name == "obstacle"
    }

    /// Attempt to move from `from` toward `to`. If `to` is blocked, tries X-only then Y-only slides.
    static func resolvedMove(from: CGPoint, to: CGPoint, radius: CGFloat, in scene: (SKScene & SafeFrameProviding)) -> CGPoint {
        if !isBlocked(to, in: scene) { return to }

        // Try slide on X only
        let xOnly = CGPoint(x: to.x, y: from.y)
        if !isBlocked(xOnly, in: scene) { return xOnly }

        // Try slide on Y only
        let yOnly = CGPoint(x: from.x, y: to.y)
        if !isBlocked(yOnly, in: scene) { return yOnly }

        // Give up (stay put)
        return from
    }
}
