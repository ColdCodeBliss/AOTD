import Foundation

class LevelLoader {
    static func loadLevels() -> [Level]? {
        guard let url = Bundle.main.url(forResource: "levels", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        
        do {
            let decoded = try JSONDecoder().decode([LevelJSON].self, from: data)
            return decoded.map { Level(terrain: $0.terrain,
                                       zombieCount: $0.zombieCount,
                                       zombieHealth: $0.zombieHealth,
                                       zombieSpeed: CGFloat($0.zombieSpeed)) }
        } catch {
            print("Error loading levels.json: \(error)")
            return nil
        }
    }
    
    private struct LevelJSON: Decodable {
        var terrain: String
        var zombieCount: Int
        var zombieHealth: Int
        var zombieSpeed: Double
    }
}
