import Foundation
import Combine

enum FavoriteType: String, Codable {
    case live
    case vod // Movies and Series
}

struct FavoriteItem: Codable, Identifiable {
    let id: String // streamId
    let name: String
    let logoUrl: URL?
    let type: FavoriteType
    let sourceUrl: String
    var isSeries: Bool? = false // Optional for backward compatibility
}

/// Manages favorites for Live TV and VOD content per source
@MainActor
class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    private let userDefaults = UserDefaults.standard
    private let favoritesKey = "favorites"
    
    @Published private var favorites: [FavoriteItem] = []
    
    private init() {
        loadFavorites()
    }
    
    func addFavorite(channel: Channel, sourceUrl: String) {
        let type: FavoriteType = (channel.categoryId.lowercased().contains("live") || channel.groupTitle?.lowercased().contains("live") == true) ? .live : .vod
        
        let item = FavoriteItem(
            id: channel.streamId,
            name: channel.name,
            logoUrl: channel.logoUrl,
            type: type,
            sourceUrl: sourceUrl,
            isSeries: channel.isSeries
        )
        
        if !isFavorite(streamId: channel.streamId, sourceUrl: sourceUrl) {
            favorites.append(item)
            persistFavorites()
            objectWillChange.send()
            print("DEBUG: Added favorite - \(item.name) (\(item.type.rawValue), isSeries: \(channel.isSeries))")
        }
    }
    
    func removeFavorite(streamId: String, sourceUrl: String) {
        if let index = favorites.firstIndex(where: { $0.id == streamId && $0.sourceUrl == sourceUrl }) {
            favorites.remove(at: index)
            persistFavorites()
            objectWillChange.send()
            print("DEBUG: Removed favorite ID: \(streamId)")
        }
    }
    
    func toggleFavorite(channel: Channel, sourceUrl: String) {
        if isFavorite(streamId: channel.streamId, sourceUrl: sourceUrl) {
            removeFavorite(streamId: channel.streamId, sourceUrl: sourceUrl)
        } else {
            addFavorite(channel: channel, sourceUrl: sourceUrl)
        }
    }
    
    func isFavorite(streamId: String, sourceUrl: String) -> Bool {
        return favorites.contains { $0.id == streamId && $0.sourceUrl == sourceUrl }
    }
    
    func getFavorites(for sourceUrl: String, type: FavoriteType) -> [FavoriteItem] {
        return favorites.filter { $0.sourceUrl == sourceUrl && $0.type == type }
    }
    
    private func loadFavorites() {
        if let data = userDefaults.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([FavoriteItem].self, from: data) {
            favorites = decoded
            print("DEBUG: FavoritesManager loaded \(favorites.count) items")
        }
    }
    
    private func persistFavorites() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            userDefaults.set(encoded, forKey: favoritesKey)
        }
    }
}
