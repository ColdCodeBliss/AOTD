import SpriteKit

/// Central place to choose and lay out level terrain.
/// Also attaches/removes the optional collision tilemap for the City level.
struct TerrainManager {
    enum Terrain: String, CaseIterable {
        case forest
        case desert
        case city   // uses "apoc_city" image + JSON tilemap
    }

    /// Simple, editable banding by level.
    /// NOTE: We add (3...3, .city) so Level 3 is your apoc_city map.
    var levelBands: [(ClosedRange<Int>, Terrain)] = [
        (3...3,   .city),   // Level 3 = City (tilemap)
        (1...20,  .forest),
        (21...60, .desert),
        (61...100, .city)
    ]

    /// Decide which terrain a given level should use.
    func terrain(for level: Int) -> Terrain {
        if let match = levelBands.first(where: { $0.0.contains(level) })?.1 {
            return match
        }
        let all = Terrain.allCases
        return all[(max(1, level) - 1) % all.count]
    }

    /// Texture name per terrain (atlas-friendly).
    private func textureName(for terrain: Terrain) -> String {
        switch terrain {
        case .forest: return "forest"
        case .desert: return "desert"
        case .city:   return "apoc_city" // image inside Terrains.atlas
        }
    }

    /// Create (or reuse) and apply the correct terrain node for a level.
    /// Also creates/updates an optional tilemap for the City terrain.
    /// - Returns: (background sprite, optional tilemap node)
    @discardableResult
    func applyTerrain(for level: Int,
                      in scene: SKScene & SafeFrameProviding,
                      existingNode: SKSpriteNode?,
                      existingTilemap: SKNode?) -> (bg: SKSpriteNode, tilemap: SKNode?) {

        let chosen = terrain(for: level)

        // --- Background: reuse if possible
        let bg: SKSpriteNode
        if let node = existingNode,
           node.userData?["terrainName"] as? String == chosen.rawValue {
            bg = node
        } else {
            let tex = SKTexture(imageNamed: textureName(for: chosen))
            let node = SKSpriteNode(texture: tex)
            node.name = "terrain"
            node.zPosition = -100
            node.userData = (node.userData ?? NSMutableDictionary())
            node.userData?["terrainName"] = chosen.rawValue

            existingNode?.removeFromParent()
            scene.addChild(node)
            bg = node
        }

        // Layout background to fill the scene (aspect-fill + center)
        layout(node: bg, in: scene)

        // --- Tilemap (City only)
        var tilemapNode: SKNode? = existingTilemap
        if chosen == .city {
            if let _ = tilemapNode {
                // Re-layout the current city map to the scene (aspect-fill + center)
                CityTilemap.layout(in: scene)
            } else {
                // Create and attach a new one above terrain
                tilemapNode = CityTilemap.attach(to: scene, below: bg)
            }
        } else {
            // Remove any previous city tilemap when switching away
            if let map = tilemapNode {
                map.removeFromParent()
            }
            tilemapNode = nil
        }

        return (bg, tilemapNode)
    }

    /// Layout to **aspect-fill** the scene’s size and center it.
    func layout(node: SKSpriteNode?, in scene: SKScene & SafeFrameProviding) {
        guard let node = node, let tex = node.texture else { return }
        let sceneW = scene.size.width
        let sceneH = scene.size.height

        let texW = tex.size().width
        let texH = tex.size().height
        guard texW > 0, texH > 0 else { return }

        let scale = max(sceneW / texW, sceneH / texH)
        node.size = CGSize(width: texW * scale, height: texH * scale)
        node.position = CGPoint(x: sceneW * 0.5, y: sceneH * 0.5)
    }
}

/// Protocol so TerrainManager can ask the scene for its safe frame
/// without importing your extension directly.
protocol SafeFrameProviding {
    func safeFrame() -> CGRect
}
