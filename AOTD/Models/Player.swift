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
    // Fine-tune forward nudge (increase to move away from muzzle)
    private var muzzleNudgeForward: CGFloat = 0
    // Fine-tune lateral nudge (perpendicular to barrel; positive values move to local +Y)
    private var muzzleNudgeLateral: CGFloat = -14 // lower the number to move more right

    // [FLASH NUDGE] — independent offsets for the muzzle flash visual
    private var flashNudgeForward: CGFloat = -10     // +X moves flash farther out the barrel
    private var flashNudgeLateral: CGFloat = 0     // +Y moves flash to the "right" side of barrel

    init(sprite: SKSpriteNode, weapon: Weapon) {
        self.sprite = sprite
        self.currentWeapon = weapon

        // Attach the muzzle so it rotates with the player.
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

    // [FLASH NUDGE] — tweak flash placement independently of bullet origin
    func setMuzzleFlashNudges(forward: CGFloat? = nil, lateral: CGFloat? = nil) {
        if let f = forward { flashNudgeForward = f }
        if let l = lateral { flashNudgeLateral = l }
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

            // --- Cone muzzle flash (attached to the muzzle) ---
            let flash = self.makeMuzzleFlash(for: self.currentWeapon)

            // [FLASH NUDGE] — position the flash slightly forward/right relative to the muzzle tip
            flash.position = CGPoint(x: self.flashNudgeForward, y: self.flashNudgeLateral)

            self.muzzle.addChild(flash)

            // Quick pop + fade
            flash.alpha = flash.alpha * 0.9
            flash.setScale(0.9)
            flash.run(.sequence([
                .group([
                    .scale(to: 1.12, duration: 0.06),
                    .fadeOut(withDuration: 0.10)
                ]),
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

    // MARK: - Muzzle flash builder (cone)
    private func makeMuzzleFlash(for weapon: Weapon) -> SKNode {
        // Keep your tuned values
        let scale: CGFloat = 0.9
        let (length, width, coreScale): (CGFloat, CGFloat, CGFloat) = {
            switch weapon.type {
            case .machineGun:      return (10, 7, 0.25)
            case .heavyMachineGun: return (26, 16, 0.60)
            case .laserGun:        return (28, 10, 0.50)
            case .shotgun:         return (20, 18, 0.50)
            }
        }()

        let outer = SKShapeNode(path: conePath(length: length, width: width))
        outer.fillColor = SKColor(red: 1.0, green: 0.82, blue: 0.25, alpha: 0.55)
        outer.strokeColor = .clear
        outer.blendMode = .add
        outer.zPosition = 25

        let inner = SKShapeNode(path: conePath(length: length * 0.78, width: width * 0.55))
        inner.fillColor = SKColor(red: 1.0, green: 0.95, blue: 0.55, alpha: 0.85)
        inner.strokeColor = .clear
        inner.blendMode = .add
        inner.zPosition = 26
        inner.setScale(coreScale)

        let group = SKNode()
        group.addChild(outer)
        group.addChild(inner)

        group.zRotation = CGFloat.random(in: -0.05...0.05)
        group.setScale(scale)
        return group
    }

    private func conePath(length: CGFloat, width: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: length, y:  width * 0.5))
        path.addLine(to: CGPoint(x: length, y: -width * 0.5))
        path.closeSubpath()
        return path
    }
}
