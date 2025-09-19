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

    // Graphics/perf hints (set by GameScene)
    var lowEffectsEnabled: Bool = false
    var spawnFPS30CapHint: Bool = false
    var shadowsDisabled: Bool = false

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
        let interval = lowEffectsEnabled ? 1.25 : 1.0 // slightly slower when low effects
        spawnTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
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

        // Max active zombies at once
        let cap = lowEffectsEnabled ? 2 : 3
        let maxActiveZombies = min(cap, maxZombiesThisRound - zombiesSpawnedThisRound)

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
