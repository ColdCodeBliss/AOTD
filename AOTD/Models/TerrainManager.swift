//
//  TerrainManager.swift
//  AOTD
//
//  Created by Ryan Bliss on 9/20/25.
//


import SpriteKit

/// Handles per-level terrain backgrounds.
/// - Uses a simple naming/mapping strategy you can expand later.
/// - Scales to fill the scene and sits behind all gameplay nodes.
final class TerrainManager {
    private weak var scene: SKScene?
    private var background: SKSpriteNode?

    /// Attach to a scene (call from GameScene.didMove).
    func attach(to scene: SKScene) {
        self.scene = scene
        if background == nil {
            let bg = SKSpriteNode()
            bg.zPosition = -1000        // always behind
            bg.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            bg.name = "terrainBackground"
            scene.addChild(bg)
            background = bg
        }
        resizeToScene()
    }

    /// Apply terrain for the given level number.
    /// Default mapping: Level 1 → "forest.png". Expand the mapping as you add art.
    func applyTerrain(for level: Int) {
        guard let scene = scene else { return }
        let name = textureName(for: level)
        let tex  = SKTexture(imageNamed: name)
        background?.texture = tex
        background?.color = .clear
        background?.size = tex.size()
        background?.position = CGPoint(x: scene.size.width * 0.5, y: scene.size.height * 0.5)
        resizeToScene()
    }

    /// Call from GameScene.didChangeSize to keep fill intact on rotation / device changes.
    func resizeToScene() {
        guard let scene = scene, let bg = background, let _ = bg.texture else { return }
        // Scale-to-fill while preserving aspect ratio
        let sceneW = scene.size.width
        let sceneH = scene.size.height
        let texW = bg.size.width
        let texH = bg.size.height

        if texW == 0 || texH == 0 { return }

        let scaleX = sceneW / texW
        let scaleY = sceneH / texH
        let scale  = max(scaleX, scaleY)        // fill
        bg.setScale(scale)
        bg.position = CGPoint(x: sceneW * 0.5, y: sceneH * 0.5)
    }

    /// Simple mapping you can extend later or replace with data from levels.json
    private func textureName(for level: Int) -> String {
        switch level {
        case 1:  return "forest"      // forest.png
        // case 2:  return "desert"
        // case 3:  return "city"
        default: return "forest"
        }
    }
}
