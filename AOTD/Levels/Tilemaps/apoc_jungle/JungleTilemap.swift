//
//  JungleTilemap.swift
//  AOTD
//

import SpriteKit
import UIKit

// JSON payload model (same as CityTilemap’s)
struct JungleTileMapPayload: Decodable {
    struct Size: Decodable { let cols: Int?; let rows: Int?; let width: Int?; let height: Int? }
    struct Layer: Decodable { let name: String; let data: [[Int]] }
    let mapSize: Size
    let tileSize: Size
    let layers: [Layer]
}

/// Utility for loading/attaching the jungle collision tilemap behind the terrain.
struct JungleTilemap: LevelTilemap {

    static let nodeName = "jungleTilemap"

    @discardableResult
    static func attach(to scene: (SKScene & SafeFrameProviding), below terrainNode: SKNode?) -> SKTileMapNode? {
        guard let map = try? loadMap() else { return nil }
        layout(map: map, in: scene)

        let zBelow = (terrainNode?.zPosition ?? -1000)
        map.zPosition = zBelow + 1
        map.name = nodeName

        scene.childNode(withName: nodeName)?.removeFromParent()
        scene.addChild(map)
        return map
    }

    static func layout(in scene: (SKScene & SafeFrameProviding)) {
        guard let map = scene.childNode(withName: nodeName) as? SKTileMapNode else { return }
        layout(map: map, in: scene)
    }

    static func remove(from scene: SKScene) {
        scene.childNode(withName: nodeName)?.removeFromParent()
    }

    // MARK: - Collision queries

    static func isBlocked(_ p: CGPoint, in scene: (SKScene & SafeFrameProviding)) -> Bool {
        guard let map = currentMap(in: scene),
              let (c, r) = worldToTile(p, in: scene) else { return false }
        return map.tileGroup(atColumn: c, row: r)?.name == "obstacle"
    }

    static func resolvedMove(from: CGPoint, to: CGPoint, radius: CGFloat, in scene: (SKScene & SafeFrameProviding)) -> CGPoint {
        // Same simple center-sample + slide heuristic used for City
        if !isBlocked(to, in: scene) { return to }
        let xOnly = CGPoint(x: to.x, y: from.y)
        if !isBlocked(xOnly, in: scene) { return xOnly }
        let yOnly = CGPoint(x: from.x, y: to.y)
        if !isBlocked(yOnly, in: scene) { return yOnly }
        return from
    }

    // MARK: - Internals

    private static func loadMap() throws -> SKTileMapNode {
        // 1) Load JSON
        let url = Bundle.main.url(forResource: "tilemap_apoc_jungle_6px_tiles_collision", withExtension: "json")!
        let payload = try JSONDecoder().decode(JungleTileMapPayload.self, from: Data(contentsOf: url))
        let cols = payload.mapSize.cols!
        let rows = payload.mapSize.rows!
        let tsW = CGFloat(payload.tileSize.width!)
        let tsH = CGFloat(payload.tileSize.height!)
        let tileSize = CGSize(width: tsW, height: tsH)

        // 2) Tileset (walkable/obstacle)
        let walkDef = SKTileDefinition(texture: solidTexture(color: .clear, size: tileSize), size: tileSize)
        let obsDef  = SKTileDefinition(texture: solidTexture(color: UIColor.white.withAlphaComponent(0.001), size: tileSize), size: tileSize)

        let walkRule = SKTileGroupRule(adjacency: .adjacencyAll, tileDefinitions: [walkDef])
        let obsRule  = SKTileGroupRule(adjacency: .adjacencyAll, tileDefinitions: [obsDef])

        let walkGroup = SKTileGroup(rules: [walkRule]); walkGroup.name = "walkable"
        let obsGroup  = SKTileGroup(rules: [obsRule]);  obsGroup.name  = "obstacle"

        let tileSet = SKTileSet(tileGroups: [walkGroup, obsGroup], tileSetType: .grid)

        // 3) Map
        let map = SKTileMapNode(tileSet: tileSet, columns: cols, rows: rows, tileSize: tileSize)

        // 4) Fill + static physics on obstacles
        guard let grid = payload.layers.first(where: { $0.name.lowercased() == "collision" })?.data else {
            return map
        }
        for r in 0..<rows {
            for c in 0..<cols {
                let val = grid[r][c]
                let group = (val == 1) ? obsGroup : walkGroup
                let rr = rows - 1 - r
                map.setTileGroup(group, forColumn: c, row: rr)

                if group === obsGroup {
                    let n = SKNode()
                    n.position = map.centerOfTile(atColumn: c, row: rr)
                    n.physicsBody = SKPhysicsBody(rectangleOf: tileSize)
                    n.physicsBody?.isDynamic = false
                    n.physicsBody?.categoryBitMask = 0x1 << 1
                    n.physicsBody?.collisionBitMask = 0xFFFFFFFF
                    n.physicsBody?.contactTestBitMask = 0
                    map.addChild(n)
                }
            }
        }
        return map
    }

    private static func layout(map: SKTileMapNode, in scene: (SKScene & SafeFrameProviding)) {
        let sceneW = scene.size.width, sceneH = scene.size.height
        let mapSize = CGSize(width: CGFloat(map.numberOfColumns) * map.tileSize.width,
                             height: CGFloat(map.numberOfRows) * map.tileSize.height)
        guard mapSize.width > 0, mapSize.height > 0 else { return }

        // Aspect-fill like the background, centered
        let scale = max(sceneW / mapSize.width, sceneH / mapSize.height)
        map.xScale = scale
        map.yScale = scale
        map.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        map.position = CGPoint(x: sceneW * 0.5, y: sceneH * 0.5)
    }

    private static func currentMap(in scene: SKScene) -> SKTileMapNode? {
        scene.childNode(withName: nodeName) as? SKTileMapNode
    }

    private static func worldToTile(_ p: CGPoint, in scene: (SKScene & SafeFrameProviding)) -> (c: Int, r: Int)? {
        guard let map = currentMap(in: scene) else { return nil }
        // Convert world → local tilemap space
        let local = CGPoint(x: (p.x - map.position.x) / map.xScale + (CGFloat(map.numberOfColumns) * map.tileSize.width) * 0.5,
                            y: (p.y - map.position.y) / map.yScale + (CGFloat(map.numberOfRows)    * map.tileSize.height) * 0.5)

        let c = Int(local.x / map.tileSize.width)
        let r = Int(local.y / map.tileSize.height)
        guard c >= 0, r >= 0, c < map.numberOfColumns, r < map.numberOfRows else { return nil }
        return (c, r)
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
