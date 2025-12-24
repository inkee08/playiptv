import Foundation

struct RecentVODItem: Codable, Identifiable {
    let id: String // streamId
    let name: String
    let logoUrl: URL?
    let lastWatched: Date
    let sourceUrl: String
    let isSeries: Bool
}

/// Manages recently watched VOD content (movies and series) per source
@MainActor
class RecentVODManager: ObservableObject {
    static let shared = RecentVODManager()
    
    private let userDefaults = UserDefaults.standard
    private let recentsKey = "recentVOD"
    
    @Published private var recents: [RecentVODItem] = []
    
    private init() {
        // Migrate from old key if exists
        if userDefaults.data(forKey: "recentSeries") != nil {
            userDefaults.removeObject(forKey: "recentSeries")
        }
        loadRecents()
        print("DEBUG: RecentVODManager loaded \(recents.count) items")
    }
    
    func addRecentVOD(streamId: String, name: String, logoUrl: URL?, sourceUrl: String, isSeries: Bool) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("DEBUG: ⭐️ ADDING TO RECENT LIST")
        print("DEBUG: Name: \(name)")
        print("DEBUG: StreamID: \(streamId)")
        print("DEBUG: Is Series: \(isSeries)")
        print("DEBUG: Source: \(sourceUrl)")
        print("DEBUG: Call stack:")
        Thread.callStackSymbols.prefix(5).forEach { print("  \($0)") }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Remove existing entry for this item
        recents.removeAll { $0.id == streamId }
        
        // Add to front
        let item = RecentVODItem(
            id: streamId,
            name: name,
            logoUrl: logoUrl,
            lastWatched: Date(),
            sourceUrl: sourceUrl,
            isSeries: isSeries
        )
        recents.insert(item, at: 0)
        
        // Keep only last 50 items total (across all sources)
        if recents.count > 50 {
            recents = Array(recents.prefix(50))
        }
        
        persistRecents()
        print("DEBUG: Total recent items after add: \(recents.count)")
    }
    
    func getRecents(for sourceUrl: String, limit: Int = 10) -> [RecentVODItem] {
        let filtered = recents.filter { $0.sourceUrl == sourceUrl }
        print("DEBUG: Getting recents for \(sourceUrl) - found \(filtered.count) items")
        return Array(filtered.prefix(limit))
    }
    
    func clearAll() {
        recents.removeAll()
        userDefaults.removeObject(forKey: recentsKey)
        userDefaults.synchronize()
        objectWillChange.send()
        print("DEBUG: Cleared all recent VOD items")
    }
    
    private func loadRecents() {
        if let data = userDefaults.data(forKey: recentsKey),
           let decoded = try? JSONDecoder().decode([RecentVODItem].self, from: data) {
            recents = decoded
        }
    }
    
    private func persistRecents() {
        if let encoded = try? JSONEncoder().encode(recents) {
            userDefaults.set(encoded, forKey: recentsKey)
        }
    }
}
