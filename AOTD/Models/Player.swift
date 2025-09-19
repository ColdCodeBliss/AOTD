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
    var isShooting: Bool = false
    private var currentShootingDirection: CGVector = CGVector(dx: 0, dy: 1) // default up

    init(sprite: SKSpriteNode, weapon: Weapon) {
        self.sprite = sprite
        self.currentWeapon = weapon
    }

    // MARK: - Movement & Rotation
    func move(direction: CGVector) {
        let dx = direction.dx * speed
        let dy = direction.dy * speed
        sprite.position.x += dx
        sprite.position.y += dy
    }

    func rotateToDirection(direction: CGVector) {
        sprite.zRotation = atan2(direction.dy, direction.dx)
        // Update current shooting direction as well
        currentShootingDirection = direction
    }

    // MARK: - Shooting
    func startShooting(in scene: SKScene) {
        guard !isShooting else { return }
        isShooting = true

        shootingTimer = Timer.scheduledTimer(withTimeInterval: currentWeapon.fireRate, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Always use the latest joystick direction
            self.currentWeapon.fire(from: self.sprite.position, direction: self.currentShootingDirection, in: scene)
        }
    }

    func stopShooting() {
        shootingTimer?.invalidate()
        shootingTimer = nil
        isShooting = false
    }

    func updateShootingDirection(direction: CGVector) {
        currentShootingDirection = direction
        rotateToDirection(direction: direction)
    }

    // MARK: - Damage Handling
    func takeDamage() {
        guard !isInvulnerable else { return }

        if armorBuffActive {
            armorBuffActive = false
            print("Armor absorbed damage! Player still has \(lives) lives.")
            respawn()
            return
        }

        lives -= 1
        print("Player hit! Lives remaining: \(lives)")

        if lives <= 0 {
            die()
        } else {
            respawn()
        }
    }

    func activateArmorBuff() {
        armorBuffActive = true
        print("Armor buff activated!")
    }

    // MARK: - Respawn & Invulnerability
    func respawn() {
        guard let scene = sprite.scene else { return }

        sprite.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        isInvulnerable = true

        let fadeOut = SKAction.fadeAlpha(to: 0.2, duration: 0.3)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        let flicker = SKAction.sequence([fadeOut, fadeIn])
        let flickerRepeat = SKAction.repeat(flicker, count: 5)
        sprite.run(flickerRepeat) { [weak self] in
            self?.isInvulnerable = false
        }
    }

    // MARK: - Death
    func die() {
        print("Player has died!")
        sprite.removeFromParent()
        stopShooting()
    }
}
