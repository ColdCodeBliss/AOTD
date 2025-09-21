import SpriteKit

/// Central place to choose and lay out level terrain.
struct TerrainManager {
    enum Terrain: String, CaseIterable {
        case forest
        case desert
        case city
    }

    /// Simple, editable banding by level. If a level isn’t in any band,
    /// we fall back to cycling through all terrains.
    var levelBands: [(ClosedRange<Int>, Terrain)] = [
        (1...20,  .forest),
        (21...60, .desert),
        (61...100, .city)
    ]

    /// Decide which terrain a given level should use.
    func terrain(for level: Int) -> Terrain {
        if let match = levelBands.first(where: { $0.0.contains(level) })?.1 {
            return match
        }
        // Fallback: cycle by level if out of configured bands
        let all = Terrain.allCases
        return all[(max(1, level) - 1) % all.count]
    }

    /// Create (or reuse) and apply the correct terrain node for a level.
    /// Returns the node you should keep as `terrainNode`.
    @discardableResult
    func applyTerrain(for level: Int,
                      in scene: SKScene & SafeFrameProviding,
                      existingNode: SKSpriteNode?) -> SKSpriteNode {
        let chosen = terrain(for: level)

        // Reuse if possible
        if let node = existingNode,
           node.userData?["terrainName"] as? String == chosen.rawValue {
            layout(node: node, in: scene)
            return node
        }

        // Build a fresh node
        let tex = SKTexture(imageNamed: chosen.rawValue)  // loads from Terrains.atlas transparently
        let node = SKSpriteNode(texture: tex)
        node.name = "terrain"
        node.zPosition = -100
        node.userData = (node.userData ?? NSMutableDictionary())
        node.userData?["terrainName"] = chosen.rawValue

        // If replacing an old one, swap in-place to avoid changing z-order relative to other HUD
        if let old = existingNode {
            old.removeFromParent()
        }
        scene.addChild(node)
        layout(node: node, in: scene)
        return node
    }

    /// Layout to **aspect-fill** the scene’s safe frame and center it.
    func layout(node: SKSpriteNode?, in scene: SKScene & SafeFrameProviding) {
        guard let node = node, let tex = node.texture else { return }
        let r = scene.safeFrame()
        let targetW = r.width
        let targetH = r.height

        let texW = tex.size().width
        let texH = tex.size().height
        let scale = max(targetW / texW, targetH / texH)

        node.size = CGSize(width: texW * scale, height: texH * scale)
        node.position = CGPoint(x: r.midX, y: r.midY)
    }
}

/// Protocol so TerrainManager can ask the scene for its safe frame
/// without importing your extension directly.
protocol SafeFrameProviding {
    func safeFrame() -> CGRect
}
