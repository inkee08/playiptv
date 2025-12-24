import Foundation

enum StreamType: String, Codable {
    case m3u
    case xtream
}

enum CategoryType: String, CaseIterable, Identifiable {
    case live
    case movie
    case series
    
    var id: String { rawValue }
}

struct Category: Identifiable, Hashable {
    let id: String
    let name: String
    let type: CategoryType
}

struct Channel: Identifiable, Hashable {
    let id: UUID = UUID() // Unique ID for UI stability
    let streamId: String // The actual ID from source (URL or API ID)
    let name: String
    let logoUrl: URL?
    let streamUrl: URL
    let categoryId: String
    let groupTitle: String? // Raw group title from M3U
    let isSeries: Bool // Flag to indicate if this is a series requiring episode selection
}

struct Episode: Identifiable, Hashable {
    let id: String
    let episodeNum: Int
    let seasonNum: Int
    let title: String?
    let streamUrl: URL
    let containerExtension: String
}

struct SeriesInfo {
    let seriesId: String
    let episodes: [Episode]
}

struct Source: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var type: StreamType
    
    // M3U
    var m3uUrl: String?
    
    // Xtream
    var xtreamUrl: String?
    var xtreamUser: String?
    var xtreamPass: String?
    
    var url: URL? {
        if type == .m3u, let str = m3uUrl { return URL(string: str) }
        if type == .xtream, let str = xtreamUrl { return URL(string: str) }
        return nil
    }
}
