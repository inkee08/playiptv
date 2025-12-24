import Foundation

enum XtreamError: Error {
    case invalidURL
    case authenticationFailed
    case networkError
    case decodingError
}

struct XtreamClient {
    let baseURL: URL
    let serverURL: URL // Base server URL without player_api.php
    let username: String
    let password: String
    
    init?(url: String, username: String, password: String) {
        guard let validURL = URL(string: url) else { return nil }
        self.baseURL = validURL
        
        // Extract server URL (remove player_api.php if present)
        var serverURLString = url
        if serverURLString.hasSuffix("/player_api.php") {
            serverURLString = String(serverURLString.dropLast("/player_api.php".count))
        } else if serverURLString.hasSuffix("player_api.php") {
            serverURLString = String(serverURLString.dropLast("player_api.php".count))
        }
        
        guard let validServerURL = URL(string: serverURLString) else { return nil }
        self.serverURL = validServerURL
        
        self.username = username
        self.password = password
    }
    
    // Construct authenticated URL
    private func playerApiURL(action: String) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent("player_api.php"), resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: action)
        ]
        return components?.url
    }
    
    // Just verifying login
    func authenticate() async throws -> Bool {
        // Xtream login check usually involves calling get_live_categories or just checking user_info
        // A common way is asking for user info.
        // But for simplicity, we can try to fetch live categories.
        
        guard let url = playerApiURL(action: "get_live_categories") else {
            throw XtreamError.invalidURL
        }
        
        let (_, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            return true
        }
        return false
    }
    
    func fetchLiveStreams(categoryId: String?) async throws -> [Channel] {
        var components = URLComponents(url: baseURL.appendingPathComponent("player_api.php"), resolvingAgainstBaseURL: true)
        var queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_live_streams")
        ]
        if let catId = categoryId {
            queryItems.append(URLQueryItem(name: "category_id", value: catId))
        }
        components?.queryItems = queryItems
        
        guard let url = components?.url else { throw XtreamError.invalidURL }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        
        // Xtream returns partial JSON matching our fields sometimes, but we need a DTO
        // Creating a local DTO structure for decoding
        struct XtreamStreamDTO: Decodable {
            let stream_id: Int
            let name: String
            let stream_icon: String?
            let category_id: String?
        }
        
        let streams = try decoder.decode([XtreamStreamDTO].self, from: data)
        
        return streams.map { dto in
            // Xtream live stream URL format: http://domain:port/live/username/password/stream_id.ts
            // Use serverURL (without player_api.php) as base
            var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: true)
            components?.path = "/live/\(username)/\(password)/\(dto.stream_id).ts"
            
            let streamUrl = components?.url ?? serverURL
            print("DEBUG: Constructed Live URL: \(streamUrl.absoluteString)")
            
            return Channel(
                streamId: String(dto.stream_id),
                name: dto.name,
                logoUrl: dto.stream_icon != nil ? URL(string: dto.stream_icon!) : nil,
                streamUrl: streamUrl,
                categoryId: dto.category_id ?? "0",
                groupTitle: nil,
                isSeries: false
            )
        }
    }
    
    // Fetches Movies (VOD)
    func fetchVODStreams(categoryId: String?) async throws -> [Channel] {
        var components = URLComponents(url: baseURL.appendingPathComponent("player_api.php"), resolvingAgainstBaseURL: true)
        var queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_vod_streams")
        ]
        if let catId = categoryId {
            queryItems.append(URLQueryItem(name: "category_id", value: catId))
        }
        components?.queryItems = queryItems
        
        guard let url = components?.url else { throw XtreamError.invalidURL }
        
        // VOD DTO
        struct XtreamVODDTO: Decodable {
            let stream_id: Int
            let name: String
            let stream_icon: String?
            let category_id: String?
            let container_extension: String?
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        let vods = try decoder.decode([XtreamVODDTO].self, from: data)
        
        return vods.map { dto in
            // VOD URL: http://domain:port/movie/username/password/stream_id.ext
            let ext = dto.container_extension ?? "mp4"
            
            var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: true)
            components?.path = "/movie/\(username)/\(password)/\(dto.stream_id).\(ext)"
            
            let streamUrl = components?.url ?? serverURL
            print("DEBUG: Constructed VOD URL: \(streamUrl.absoluteString)")
            
            return Channel(
                streamId: String(dto.stream_id),
                name: dto.name,
                logoUrl: dto.stream_icon != nil ? URL(string: dto.stream_icon!) : nil,
                streamUrl: streamUrl,
                categoryId: dto.category_id ?? "0",
                groupTitle: nil,
                isSeries: false
            )
        }
    }
    
    // Fetches Series
    func fetchSeries(categoryId: String?) async throws -> [Channel] {
        var components = URLComponents(url: baseURL.appendingPathComponent("player_api.php"), resolvingAgainstBaseURL: true)
        var queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_series")
        ]
        if let catId = categoryId {
            queryItems.append(URLQueryItem(name: "category_id", value: catId))
        }
        components?.queryItems = queryItems
        
        guard let url = components?.url else { throw XtreamError.invalidURL }
        
        struct XtreamSeriesDTO: Decodable {
            let series_id: Int
            let name: String
            let cover: String?
            let category_id: String?
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        let series = try decoder.decode([XtreamSeriesDTO].self, from: data)
        
        return series.map { dto in
            // Series don't have a single stream URL usually, they have episodes.
            // But for the channel list, we track them here.
            // We might need a separate call to get episodes for a series.
            // For now, we'll placeholder the URL or use a special scheme to indicate it's a series to open.
            let seriesUrl = URL(string: "series://\(dto.series_id)")!
            
            return Channel(
                streamId: String(dto.series_id),
                name: dto.name,
                logoUrl: dto.cover != nil ? URL(string: dto.cover!) : nil,
                streamUrl: seriesUrl,
                categoryId: dto.category_id ?? "0",
                groupTitle: nil,
                isSeries: true
            )
        }
    }
    
    // Fetch episodes for a specific series
    func fetchSeriesInfo(seriesId: String) async throws -> SeriesInfo {
        var components = URLComponents(url: baseURL.appendingPathComponent("player_api.php"), resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_series_info"),
            URLQueryItem(name: "series_id", value: seriesId)
        ]
        
        guard let url = components?.url else { throw XtreamError.invalidURL }
        
        struct SeriesInfoDTO: Decodable {
            let episodes: [String: [EpisodeDTO]]
        }
        
        struct EpisodeDTO: Decodable {
            let id: String
            let episode_num: Int
            let season: Int
            let title: String?
            let container_extension: String
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        let info = try decoder.decode(SeriesInfoDTO.self, from: data)
        
        var allEpisodes: [Episode] = []
        for (_, seasonEpisodes) in info.episodes {
            for ep in seasonEpisodes {
                // Episode URL: http://domain:port/series/username/password/episode_id.ext
                var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: true)
                components?.path = "/series/\(username)/\(password)/\(ep.id).\(ep.container_extension)"
                
                let episodeUrl = components?.url ?? serverURL
                print("DEBUG: Constructed Episode URL: \(episodeUrl.absoluteString)")
                
                allEpisodes.append(Episode(
                    id: ep.id,
                    episodeNum: ep.episode_num,
                    seasonNum: ep.season,
                    title: ep.title,
                    streamUrl: episodeUrl,
                    containerExtension: ep.container_extension
                ))
            }
        }
        
        return SeriesInfo(seriesId: seriesId, episodes: allEpisodes.sorted { ($0.seasonNum, $0.episodeNum) < ($1.seasonNum, $1.episodeNum) })
    }
}
