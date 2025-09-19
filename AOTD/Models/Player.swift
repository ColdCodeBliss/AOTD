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

    // Joystick / aim state
    private var currentShootingDirection: CGVector = CGVector(dx: 0, dy: 1) // default up

    // --- Muzzle anchor (at gun tip, in player-local space) ---
    private let muzzle = SKNode()

    // Base forward offset toward the barrel (along local +X when zRotation == 0)
    private var baseMuzzleOffset: CGFloat = 22
    // Per-weapon forward tweak
    private var weaponMuzzleOffset: CGFloat = 0
    // Fine-tune forward nudge (what you already asked for)
    private var muzzleNudgeForward: CGFloat = 0 // increse to move away from muzzle
    // NEW: fine-tune lateral nudge (perpendicular to barrel; positive values move to local +Y)
    private var muzzleNudgeLateral: CGFloat = -14 //lower the number to move more right

    init(sprite: SKSpriteNode, weapon: Weapon) {
        self.sprite = sprite
        self.currentWeapon = weapon

        // Attach the muzzle so it rotates with the player.
        // Forward (x) moves along the barrel; lateral (y) moves “right/left” relative to the barrel.
        muzzle.position = computedMuzzleLocalPosition()
        sprite.addChild(muzzle)
    }

    // Recompute local muzzle position whenever offsets/weapon change
    private func computedMuzzleLocalPosition() -> CGPoint {
        CGPoint(
            x: baseMuzzleOffset + weaponMuzzleOffset + muzzleNudgeForward + sprite.size.width * 0.25,
            y: muzzleNudgeLateral
        )
    }

    // Public helpers for tweaking
    func setWeapon(_ newWeapon: Weapon, muzzleForwardOffset: CGFloat? = nil, muzzleLateralOffset: CGFloat? = nil) {
        currentWeapon = newWeapon
        if let f = muzzleForwardOffset { weaponMuzzleOffset = f }
        if let l = muzzleLateralOffset { muzzleNudgeLateral = l }
        muzzle.position = computedMuzzleLocalPosition()
    }

    /// Adjust fine-tune nudges at runtime (e.g., from a debug menu)
    func setMuzzleNudges(forward: CGFloat? = nil, lateral: CGFloat? = nil) {
        if let f = forward { muzzleNudgeForward = f }
        if let l = lateral { muzzleNudgeLateral = l }
        muzzle.position = computedMuzzleLocalPosition()
    }

    // MARK: - Movement & Rotation
    func move(direction: CGVector) {
        let dx = direction.dx * speed
        let dy = direction.dy * speed
        sprite.position.x += dx
        sprite.position.y += dy
    }

    func rotateToDirection(direction: CGVector) {
        guard direction.dx != 0 || direction.dy != 0 else { return }
        sprite.zRotation = atan2(direction.dy, direction.dx)
        currentShootingDirection = direction
    }

    // MARK: - Shooting
    func startShooting(in scene: SKScene) {
        guard !isShooting else { return }
        isShooting = true

        shootingTimer = Timer.scheduledTimer(withTimeInterval: currentWeapon.fireRate, repeats: true) { [weak self, weak scene] _ in
            guard let self = self, let scene = scene else { return }

            // Convert muzzle (player-local) to scene/world coordinates
            let origin = scene.convert(self.muzzle.position, from: self.sprite)
            let dir = self.currentShootingDirection
            if dir.dx == 0 && dir.dy == 0 { return }

            self.currentWeapon.fire(from: origin, direction: dir, in: scene)

            // Quick muzzle flash
            let flash = SKShapeNode(circleOfRadius: 5)
            flash.fillColor = .white
            flash.strokeColor = .clear
            flash.alpha = 0.9
            flash.position = .zero
            self.muzzle.addChild(flash)
            flash.run(.sequence([
                .scale(to: 1.4, duration: 0.05),
                .fadeOut(withDuration: 0.08),
                .removeFromParent()
            ]))
        }
        if let timer = shootingTimer {
            RunLoop.current.add(timer, forMode: .common)
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
            lives = 0 // clamp
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
