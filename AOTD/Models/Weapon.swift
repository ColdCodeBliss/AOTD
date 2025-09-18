import SpriteKit

class Weapon {
    enum WeaponType { case machineGun, heavyMachineGun, laserGun, shotgun }
    var type: WeaponType
    
    init(type: WeaponType) { self.type = type }
    
    func fire(from position: CGPoint, direction: CGVector) {
        print("Firing \(type) from \(position) in direction \(direction)")
        // Implement bullet spawning, damage, and timer logic here
    }
}
