import SpriteKit

class Zombie: SKSpriteNode {
    var moveSpeed: CGFloat = 2.0
    var health: Int = 1
    var maxHealth: Int = 1
    private var isDead = false

    /// Scales the effective collision radius relative to sprite size.
    /// Lower values make zombies "harder to hit" (smaller hit box).
    /// Good starting range: 0.50 ... 0.65
    var hitRadiusScale: CGFloat = 0.55

    /// Computed effective hit radius (circle-overlap).
    var hitRadius: CGFloat {
        max(size.width, size.height) * 0.5 * hitRadiusScale
    }

    /// Baseline update signature preserved. If a tilemap is present,
    /// we resolve moves against obstacle tiles; otherwise we use simple seek.
    func update(playerPosition: CGPoint) {
        guard !isDead else { return }

        let dx = playerPosition.x - position.x
        let dy = playerPosition.y - position.y
        let distance = sqrt(dx*dx + dy*dy)
        guard distance > 0.0001 else { return }

        // Proposed straight-line movement toward the player
        let step = moveSpeed
        let vx = (dx / distance) * step
        let vy = (dy / distance) * step
        let proposed = CGPoint(x: position.x + vx, y: position.y + vy)

        if let sc = scene as? (SKScene & SafeFrameProviding) {
            // ✅ Use TilemapKit so any active map (city, jungle, etc.) is respected
            let resolved = TilemapKit.resolvedMove(from: position,
                                                   to: proposed,
                                                   radius: hitRadius,
                                                   in: sc)
            position = resolved
        } else {
            // Fallback: original movement
            position.x += vx
            position.y += vy
        }

        zRotation = atan2(dy, dx)
    }

    func takeDamage(amount: Int = 1) {
        health -= amount
        if health <= 0 { die() }
    }

    func die() {
        isDead = true
        removeFromParent()
    }
}
