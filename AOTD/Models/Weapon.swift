//
//  Weapon.swift
//  AOTD
//
//  Created by Ryan Bliss on 9/18/25.
//


class Weapon {
    enum WeaponType { case machineGun, heavyMachineGun, laserGun, shotgun }
    var type: WeaponType
    init(type: WeaponType) { self.type = type }
}
