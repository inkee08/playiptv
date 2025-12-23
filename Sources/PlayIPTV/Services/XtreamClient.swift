import Foundation

enum XtreamError: Error {
    case invalidURL
    case authenticationFailed
    case networkError
    case decodingError
}

struct XtreamClient {
    let baseURL: URL
    let username: String
    let password: String
    
    init?(url: String, username: String, password: String) {
        guard let validURL = URL(string: url) else { return nil }
        self.baseURL = validURL
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
            // Xtream live stream URL format: http://domain:port/username/password/stream_id.ts (usually)
            // or just /live/username/password/stream_id.ts
            // We need to construct the stream URL manually usually.
            
            // Assuming standard structure: baseURL/live/username/password/stream_id.ts
            let streamUrl = baseURL.appendingPathComponent("live")
                .appendingPathComponent(username)
                .appendingPathComponent(password)
                .appendingPathComponent("\(dto.stream_id).ts")
            
            return Channel(
                streamId: String(dto.stream_id),
                name: dto.name,
                logoUrl: dto.stream_icon != nil ? URL(string: dto.stream_icon!) : nil,
                streamUrl: streamUrl,
                categoryId: dto.category_id ?? "0",
                groupTitle: nil
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
            // VOD URL: /movie/username/password/stream_id.mp4 (or mkv etc)
            let ext = dto.container_extension ?? "mp4"
            let streamUrl = baseURL.appendingPathComponent("movie")
                .appendingPathComponent(username)
                .appendingPathComponent(password)
                .appendingPathComponent("\(dto.stream_id).\(ext)")
            
            return Channel(
                streamId: String(dto.stream_id),
                name: dto.name,
                logoUrl: dto.stream_icon != nil ? URL(string: dto.stream_icon!) : nil,
                streamUrl: streamUrl,
                categoryId: dto.category_id ?? "0",
                groupTitle: nil
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
                groupTitle: nil
            )
        }
    }
}
