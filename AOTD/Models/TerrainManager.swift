import SpriteKit

/// Central place to choose and lay out level terrain.
/// Also attaches/removes the optional collision tilemaps per terrain.
struct TerrainManager {
    enum Terrain: String, CaseIterable {
        case jungle      // uses "apoc_jungle" image + JSON tilemap
        case desert      // image only (for now)
        case city        // uses "apoc_city"  image + JSON tilemap
    }

    /// Simple, editable banding by level (earlier bands win).
    /// Level 1  → jungle (apoc_jungle, with tilemap)
    /// Level 3  → city   (apoc_city,   with tilemap)
    var levelBands: [(ClosedRange<Int>, Terrain)] = [
        (1...1,   .jungle),   // Level 1 = apoc_jungle (tilemap)
        (3...3,   .city),     // Level 3 = apoc_city   (tilemap)
        (2...2,   .desert),   // Level 2 = desert (no tilemap yet)
        (4...100, .jungle)    // temp default; update as you add new maps
    ]

    /// Decide which terrain a given level should use.
    func terrain(for level: Int) -> Terrain {
        if let match = levelBands.first(where: { $0.0.contains(level) })?.1 {
            return match
        }
        let all = Terrain.allCases
        return all[(max(1, level) - 1) % all.count]
    }

    /// Resolve the actual texture name for a terrain kind.
    private func textureName(for terrain: Terrain) -> String {
        switch terrain {
        case .jungle: return "apoc_jungle"
        case .desert: return "desert"
        case .city:   return "apoc_city"
        }
    }

    /// Create (or reuse) and apply the correct terrain node for a level.
    /// Also creates/updates/removes the terrain’s tilemap as needed.
    /// - Returns: (background sprite, optional tilemap node)
    @discardableResult
    func applyTerrain(for level: Int,
                      in scene: SKScene & SafeFrameProviding,
                      existingNode: SKSpriteNode?,
                      existingTilemap: SKNode?) -> (bg: SKSpriteNode, tilemap: SKNode?) {

        let chosen  = terrain(for: level)
        let texName = textureName(for: chosen)

        // --- Background: reuse if possible
        let bg: SKSpriteNode
        if let node = existingNode,
           node.userData?["terrainName"] as? String == chosen.rawValue,
           node.userData?["textureName"] as? String == texName {
            bg = node
        } else {
            let tex = SKTexture(imageNamed: texName)
            let node = SKSpriteNode(texture: tex)
            node.name = "terrain"
            node.zPosition = -100
            node.userData = (node.userData ?? NSMutableDictionary())
            node.userData?["terrainName"] = chosen.rawValue
            node.userData?["textureName"] = texName

            existingNode?.removeFromParent()
            scene.addChild(node)
            bg = node
        }

        // Layout background (aspect-fill + center)
        layout(node: bg, in: scene)

        // --- Tilemaps (attach the right one, remove the others)
        var tilemapNode: SKNode? = existingTilemap

        switch chosen {
        case .city:
            // Ensure jungle map is gone; attach/realign city
            JungleTilemap.remove(from: scene)
            if tilemapNode is SKTileMapNode {
                CityTilemap.layout(in: scene)
            } else {
                tilemapNode = CityTilemap.attach(to: scene, below: bg)
            }

        case .jungle:
            // Ensure city map is gone; attach/realign jungle
            CityTilemap.remove(from: scene)
            if tilemapNode is SKTileMapNode {
                JungleTilemap.layout(in: scene)
            } else {
                tilemapNode = JungleTilemap.attach(to: scene, below: bg)
            }

        case .desert:
            // No tilemap yet—remove any existing tilemap
            CityTilemap.remove(from: scene)
            JungleTilemap.remove(from: scene)
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
protocol SafeFrameProviding {
    func safeFrame() -> CGRect
}
