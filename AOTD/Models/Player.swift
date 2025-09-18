import SpriteKit

class Player {
    var sprite: SKSpriteNode
    var speed: CGFloat = 5.0
    var lives: Int = 3
    var armorBuffActive: Bool = false
    var isInvulnerable: Bool = false
    var currentWeapon: Weapon
    
    // Timer for automatic shooting
    private var shootingTimer: Timer?

    init(sprite: SKSpriteNode, weapon: Weapon) {
        self.sprite = sprite
        self.currentWeapon = weapon
    }

    func move(direction: CGVector) {
        let dx = direction.dx * speed
        let dy = direction.dy * speed
        sprite.position.x += dx
        sprite.position.y += dy
    }

    func rotateToDirection(direction: CGVector) {
        sprite.zRotation = atan2(direction.dy, direction.dx)
    }

    // Start continuous shooting
    func startShooting(direction: CGVector, in scene: SKScene) {
        stopShooting() // ensure no duplicate timers

        shootingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentWeapon.fire(from: self.sprite.position, direction: direction, in: scene)
        }
    }

    // Stop continuous shooting
    func stopShooting() {
        shootingTimer?.invalidate()
        shootingTimer = nil
    }

    func takeDamage() {
        guard !isInvulnerable else { return }

        lives -= 1
        print("Player hit! Lives remaining: \(lives)")

        if lives <= 0 {
            die()
        } else {
            respawn()
        }
    }

    func respawn() {
        sprite.position = CGPoint(x: sprite.scene!.size.width/2,
                                  y: sprite.scene!.size.height/2)
        isInvulnerable = true

        let fadeOut = SKAction.fadeAlpha(to: 0.2, duration: 0.3)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        let flicker = SKAction.sequence([fadeOut, fadeIn])
        let flickerRepeat = SKAction.repeat(flicker, count: 5)
        sprite.run(flickerRepeat) { [weak self] in
            self?.isInvulnerable = false
        }
    }

    func activateArmorBuff() {
        armorBuffActive = true
        print("Armor buff activated!")
    }

    func die() {
        print("Player has died!")
        sprite.removeFromParent()
        stopShooting()
    }
}
