import SpriteKit

class RoundManager {
    var currentRound: Int = 0
    var maxRounds: Int { return levelData.count }
    var levelData: [Level]
    
    // Reference to the GameScene
    weak var scene: GameScene?

    // Zombie tracking
    var zombiesSpawnedThisRound: Int = 0
    var maxZombiesThisRound: Int = 0
    var spawnTimer: Timer?

    init(levelData: [Level]) {
        self.levelData = levelData
    }

    func startRound(in scene: GameScene) {
        guard currentRound < maxRounds else { return }
        currentRound += 1
        self.scene = scene
        zombiesSpawnedThisRound = 0

        let level = levelData[currentRound - 1]
        maxZombiesThisRound = level.zombieCount

        // Start countdown before first zombies spawn
        scene.startCountdownAndLevel(spawnCallback: { [weak self] in
            self?.startSpawningZombies(for: level)
        })
    }

    private func startSpawningZombies(for level: Level) {
        spawnTimer?.invalidate()
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.spawnZombies(level: level)
        }
    }

    private func spawnZombies(level: Level) {
        guard let scene = scene else { return }
        guard zombiesSpawnedThisRound < maxZombiesThisRound else {
            spawnTimer?.invalidate()
            spawnTimer = nil
            return
        }

        // Spawn in small groups (max 3 alive at once)
        let maxActiveZombies = min(3, maxZombiesThisRound - zombiesSpawnedThisRound)
        let zombiesToSpawn = maxActiveZombies - scene.zombies.count
        guard zombiesToSpawn > 0 else { return }

        for _ in 0..<zombiesToSpawn {
            scene.spawnZombie(level: level)
            zombiesSpawnedThisRound += 1
        }
    }

    func levelCompleted() {
        spawnTimer?.invalidate()
        spawnTimer = nil
        scene?.proceedToNextLevel()
    }
}
