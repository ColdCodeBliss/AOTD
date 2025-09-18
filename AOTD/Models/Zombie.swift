import SpriteKit

class Zombie: SKSpriteNode {
    var moveSpeed: CGFloat = 2.0
    var health: Int = 1
    private var isDead: Bool = false
    
    func update(playerPosition: CGPoint) {
        guard !isDead else { return }
        
        // Calculate direction vector toward player
        let dx = playerPosition.x - position.x
        let dy = playerPosition.y - position.y
        let distance = sqrt(dx*dx + dy*dy)
        
        guard distance > 0 else { return }
        
        let velocity = CGVector(dx: (dx/distance) * moveSpeed,
                                dy: (dy/distance) * moveSpeed)
        
        position.x += velocity.dx
        position.y += velocity.dy
        
        // Rotate zombie to face the player
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
