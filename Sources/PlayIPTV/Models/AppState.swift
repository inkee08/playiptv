import SwiftUI

@Observable
class AppState {
    var channels: [Channel] = []
    var categories: [Category] = []
    var selectedCategory: Category?
    var selectedChannel: Channel?
    var searchText: String = ""
    
    // Theme support
    enum AppTheme: String, CaseIterable, Codable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        var id: String { rawValue }
    }
    var theme: AppTheme = .system
    
    var filteredChannels: [Channel] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let channelsToFilter: [Channel]
        
        if let cat = selectedCategory {
            channelsToFilter = channels.filter { $0.categoryId == cat.id || $0.groupTitle == cat.name }
        } else {
            channelsToFilter = channels
        }
        
        if text.isEmpty {
            return channelsToFilter
        } else {
            return channelsToFilter.filter { $0.name.localizedCaseInsensitiveContains(text) }
        }
    }
    
    var isLoading: Bool = false
    var errorMessage: String?
    
    // Multi-source management
    var sources: [Source] = []
    var currentSource: Source?
    
    // Temporary credentials for "Add Source" form (if needed by view, but ideally view handles this)
    // We will keep AppState clean and let View handle new source creation, then call addSource().
    
    // Load Current Source
    func loadSource(_ source: Source) async {
        self.currentSource = source
        self.channels = []
        self.categories = []
        self.selectedCategory = nil
        self.selectedChannel = nil
        
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        switch source.type {
        case .m3u:
            await loadM3U(source: source)
        case .xtream:
            await loadXtream(source: source)
        }
    }
    
    // Load M3U
    private func loadM3U(source: Source) async {
        guard let urlStr = source.m3uUrl, let url = URL(string: urlStr) else {
            await MainActor.run { errorMessage = "Invalid M3U URL"; isLoading = false }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw URLError(.cannotDecodeContentData)
            }
            
            let parsedChannels = await M3UParser.parse(content: content)
            
            let newCategories = Dictionary(grouping: parsedChannels, by: { $0.groupTitle ?? "Uncategorized" })
                .map { key, value in
                    Category(id: key, name: key, type: .live)
                }
                .sorted { $0.name < $1.name }
            
            await MainActor.run {
                self.channels = parsedChannels
                self.categories = newCategories
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // Load Xtream
    private func loadXtream(source: Source) async {
        guard let urlStr = source.xtreamUrl,
              let user = source.xtreamUser,
              let pass = source.xtreamPass,
              let client = XtreamClient(url: urlStr, username: user, password: pass) else {
            await MainActor.run { errorMessage = "Invalid Credentials"; isLoading = false }
            return
        }
        
        do {
            let authenticated = try await client.authenticate()
            if !authenticated { throw XtreamError.authenticationFailed }
            
            async let liveChannels = client.fetchLiveStreams(categoryId: nil)
            async let vodChannels = client.fetchVODStreams(categoryId: nil)
            async let seriesChannels = client.fetchSeries(categoryId: nil)
            
            let (live, vod, series) = try await (liveChannels, vodChannels, seriesChannels)
            
            // Create simplified categories
            let liveCat = Category(id: "live_all", name: "Live TV", type: .live)
            let movieCat = Category(id: "vod_all", name: "Movies", type: .movie)
            let seriesCat = Category(id: "series_all", name: "Series", type: .series)
            
            let taggedLive = live.map { Channel(streamId: $0.streamId, name: $0.name, logoUrl: $0.logoUrl, streamUrl: $0.streamUrl, categoryId: "live_all", groupTitle: "Live") }
            let taggedVod = vod.map { Channel(streamId: $0.streamId, name: $0.name, logoUrl: $0.logoUrl, streamUrl: $0.streamUrl, categoryId: "vod_all", groupTitle: "Movies") }
            let taggedSeries = series.map { Channel(streamId: $0.streamId, name: $0.name, logoUrl: $0.logoUrl, streamUrl: $0.streamUrl, categoryId: "series_all", groupTitle: "Series") }
            
            await MainActor.run {
                self.channels = taggedLive + taggedVod + taggedSeries
                self.categories = [liveCat, movieCat, seriesCat]
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func addSource(_ source: Source) {
        sources.append(source)
        Task {
            await loadSource(source)
        }
    }
    
    func removeSource(_ source: Source) {
        sources.removeAll { $0.id == source.id }
        if currentSource?.id == source.id {
            currentSource = nil
            channels = []
            categories = []
        }
    }
    
    func logout() {
        currentSource = nil
        channels = []
        categories = []
    }
}
