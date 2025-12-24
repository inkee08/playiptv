import Foundation

struct PlaybackProgress: Codable {
    let position: Double
    let duration: Double
}

/// Manages playback positions for VOD content
@MainActor
class PlaybackPositionManager: ObservableObject {
    static let shared = PlaybackPositionManager()
    
    private let userDefaults = UserDefaults.standard
    private let positionsKey = "playbackPositions"
    
    // streamId -> progress data
    @Published private var positions: [String: PlaybackProgress] = [:]
    
    private init() {
        loadPositions()
    }
    
    func savePosition(streamId: String, position: Double, duration: Double = 0) {
        // Only save if position is > 5 seconds and not near the end (last 30 seconds)
        guard position > 5 else { return }
        
        positions[streamId] = PlaybackProgress(position: position, duration: duration)
        persistPositions()
    }
    
    func getPosition(streamId: String) -> Double? {
        positions[streamId]?.position
    }
    
    func getProgress(streamId: String) -> Double? {
        guard let data = positions[streamId],
              data.duration > 0 else { return nil }
        return min(data.position / data.duration, 1.0)
    }
    
    func clearPosition(streamId: String) {
        positions.removeValue(forKey: streamId)
        persistPositions()
    }
    
    private func loadPositions() {
        if let data = userDefaults.data(forKey: positionsKey),
           let decoded = try? JSONDecoder().decode([String: PlaybackProgress].self, from: data) {
            positions = decoded
        }
    }
    
    private func persistPositions() {
        if let encoded = try? JSONEncoder().encode(positions) {
            userDefaults.set(encoded, forKey: positionsKey)
        }
    }
}
