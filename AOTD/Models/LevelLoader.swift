import Foundation
import CoreGraphics

class LevelLoader {
    static func loadLevels() -> [Level]? {
        guard let url = Bundle.main.url(forResource: "levels", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            // No file? Fall back to a sensible default seed (3 entries).
            let seed: [Level] = [
                Level(terrain: "forest", zombieCount: 5,  zombieHealth: 1, zombieSpeed: 2.0),
                Level(terrain: "desert", zombieCount: 8,  zombieHealth: 1, zombieSpeed: 2.5),
                Level(terrain: "city",   zombieCount: 10, zombieHealth: 1, zombieSpeed: 3.0)
            ]
            return expandToFifty(seed: seed)
        }

        do {
            let decoded = try JSONDecoder().decode([LevelJSON].self, from: data)
            let base = decoded.map { Level(terrain: $0.terrain,
                                           zombieCount: $0.zombieCount,
                                           zombieHealth: $0.zombieHealth,
                                           zombieSpeed: CGFloat($0.zombieSpeed)) }
            return expandToFifty(seed: base)
        } catch {
            print("Error loading levels.json: \(error)")
            return nil
        }
    }

    // Keep #1–3 exactly as provided; auto-fill #4–50 as apoc_city (terrain = "city")
    // with a mild difficulty ramp so it feels natural.
    private static func expandToFifty(seed: [Level]) -> [Level] {
        var levels = seed
        if levels.count >= 50 { return levels }

        let startIdx = levels.count + 1
        for i in startIdx...50 {
            // Simple ramp based on index; tune as you like.
            let idx = i
            let zombies   = 10 + (idx - 3) * 2            // grows gradually
            let health    = 1 + (idx / 12)                // bump every ~12 levels
            let speed     = CGFloat(3.0 + Double(idx-3) * 0.03) // gentle speed ramp

            levels.append(Level(terrain: "city",
                                zombieCount: max(zombies, 10),
                                zombieHealth: max(health, 1),
                                zombieSpeed: speed))
        }
        return levels
    }

    private struct LevelJSON: Decodable {
        var terrain: String
        var zombieCount: Int
        var zombieHealth: Int
        var zombieSpeed: Double
    }
}
