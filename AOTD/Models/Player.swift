import SpriteKit

class Player {
    var sprite: SKSpriteNode
    var speed: CGFloat = 5.0
    var health: Int = 1
    var armorBuffActive: Bool = false
    var currentWeapon: Weapon

    init(sprite: SKSpriteNode, weapon: Weapon) {
        self.sprite = sprite
        self.currentWeapon = weapon
    }

    // Move the player
    func move(direction: CGVector) {
        let dx = direction.dx * speed
        let dy = direction.dy * speed
        sprite.position.x += dx
        sprite.position.y += dy
    }

    // Rotate to face a direction
    func rotateToDirection(direction: CGVector) {
        sprite.zRotation = atan2(direction.dy, direction.dx)
    }

    // Shoot with current weapon
    // Added `in scene: SKScene` parameter to pass the scene reference
    func shoot(direction: CGVector, in scene: SKScene) {
        currentWeapon.fire(from: sprite.position, direction: direction, in: scene)
    }

    // Handle taking damage
    func takeDamage() {
        if armorBuffActive {
            armorBuffActive = false
            print("Armor absorbed damage!")
        } else {
            health -= 1
            if health <= 0 { die() }
        }
    }

    func activateArmorBuff() {
        armorBuffActive = true
        print("Armor buff activated!")
    }

    func die() {
        print("Player has died!")
        sprite.removeFromParent()
    }
}
