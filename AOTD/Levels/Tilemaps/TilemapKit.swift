import SpriteKit

/// Tilemap façade used by Player/Scene to query collision without knowing which map is active.
enum TilemapKit {

    /// All tilemap types we support. Add new ones here (e.g. GraveyardTilemap, DesertTilemap).
    private static let maps: [LevelTilemap.Type] = [
        CityTilemap.self,
        JungleTilemap.self
    ]

    /// True if any active tilemap reports the point is blocked.
    static func isBlocked(_ p: CGPoint, in scene: (SKScene & SafeFrameProviding)) -> Bool {
        for map in maps {
            if map.isBlocked(p, in: scene) { return true }
        }
        return false
    }

    /// Attempt to move from `from` toward `to`, letting the active tilemap resolve slides.
    /// If multiple maps were somehow active, we apply them in order.
    static func resolvedMove(from: CGPoint,
                             to: CGPoint,
                             radius: CGFloat,
                             in scene: (SKScene & SafeFrameProviding)) -> CGPoint {
        var pos = to
        for map in maps {
            pos = map.resolvedMove(from: from, to: pos, radius: radius, in: scene)
        }
        return pos
    }
}

/// Protocol that a level tilemap type should conform to for TilemapKit routing.
protocol LevelTilemap {
    static var nodeName: String { get }
    @discardableResult
    static func attach(to scene: (SKScene & SafeFrameProviding), below terrainNode: SKNode?) -> SKTileMapNode?
    static func layout(in scene: (SKScene & SafeFrameProviding))
    static func remove(from scene: SKScene)

    // Collision queries
    static func isBlocked(_ p: CGPoint, in scene: (SKScene & SafeFrameProviding)) -> Bool
    static func resolvedMove(from: CGPoint, to: CGPoint, radius: CGFloat, in scene: (SKScene & SafeFrameProviding)) -> CGPoint
}
