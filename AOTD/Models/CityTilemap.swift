//
//  CityTilemap.swift
//  AOTD
//
//  Build the apoc_city collision tilemap from JSON (6px tiles)
//

import SpriteKit
import UIKit

// MARK: - JSON payload

struct TileMapPayload: Decodable {
    struct Size: Decodable {
        let cols: Int?
        let rows: Int?
        let width: Int?
        let height: Int?
    }
    struct Layer: Decodable {
        let name: String
        let data: [[Int]]        // 0 = walkable, 1 = obstacle
    }
    let mapSize: Size
    let tileSize: Size
    let layers: [Layer]
}

// MARK: - Loader

/// Loads `tilemap_apoc_city_6px_tiles_collision.json` from the main bundle and
/// creates an `SKTileMapNode` with a simple two-tile tileset (walkable / obstacle).
/// Each obstacle tile gets an attached static SKPhysicsBody rectangle.
func loadApocCityTilemap() throws -> SKTileMapNode {
    // 1) JSON
    guard let url = Bundle.main.url(forResource: "tilemap_apoc_city_6px_tiles_collision",
                                    withExtension: "json") else {
        throw NSError(domain: "CityTilemap", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing JSON file in bundle"])
    }
    let payload = try JSONDecoder().decode(TileMapPayload.self, from: Data(contentsOf: url))

    let cols = payload.mapSize.cols ?? 0
    let rows = payload.mapSize.rows ?? 0
    let tsW  = payload.tileSize.width ?? 6
    let tsH  = payload.tileSize.height ?? 6
    let tileSize = CGSize(width: tsW, height: tsH)

    // 2) Minimal tileset with two definitions
    let walkTex = SKTexture(image: UIImage(color: .clear, size: tileSize))
    let obsTex  = SKTexture(image: UIImage(color: UIColor.white.withAlphaComponent(0.001),
                                           size: tileSize))

    // ⬇️ SpriteKit wants SKTileDefinition(s), not SKTexture(s)
    let walkDef = SKTileDefinition(texture: walkTex, size: tileSize)
    let obsDef  = SKTileDefinition(texture: obsTex,  size: tileSize)

    let walkRule = SKTileGroupRule(adjacency: .adjacencyAll, tileDefinitions: [walkDef])
    let obsRule  = SKTileGroupRule(adjacency: .adjacencyAll, tileDefinitions: [obsDef])

    let walkGroup = SKTileGroup(rules: [walkRule]); walkGroup.name = "walkable"
    let obsGroup  = SKTileGroup(rules: [obsRule]);  obsGroup.name  = "obstacle"

    let tileSet = SKTileSet(tileGroups: [walkGroup, obsGroup])

    // 3) Build the map
    let map = SKTileMapNode(tileSet: tileSet,
                            columns: cols,
                            rows: rows,
                            tileSize: tileSize)
    map.name = "apoc_city_collision_map"
    map.zPosition = -900  // under gameplay, above background

    guard let grid = payload.layers.first(where: { $0.name.lowercased() == "collision" })?.data else {
        return map
    }

    // 4) Populate tiles and attach simple physics bodies for obstacles
    for r in 0..<rows {
        for c in 0..<cols {
            let isObstacle = (grid[r][c] == 1)
            let rowForSpriteKit = rows - 1 - r // SpriteKit's origin is bottom-left for tilemaps
            let group = isObstacle ? obsGroup : walkGroup
            map.setTileGroup(group, forColumn: c, row: rowForSpriteKit)

            if isObstacle {
                let tileNode = SKNode()
                tileNode.position = map.centerOfTile(atColumn: c, row: rowForSpriteKit)
                tileNode.physicsBody = SKPhysicsBody(rectangleOf: tileSize)
                tileNode.physicsBody?.isDynamic = false
                tileNode.physicsBody?.categoryBitMask = 0x1 << 1 // your "Obstacle" category
                tileNode.physicsBody?.collisionBitMask = 0xFFFFFFFF
                tileNode.physicsBody?.contactTestBitMask = 0xFFFFFFFF
                map.addChild(tileNode)
            }
        }
    }

    return map
}

// MARK: - Tiny helper to make solid-color images
extension UIImage {
    convenience init(color: UIColor, size: CGSize) {
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        self.init(cgImage: img.cgImage!)
    }
}
