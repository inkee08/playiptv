import SwiftUI
import Combine

@Observable
@MainActor
class AppState {
    var channels: [Channel] = []
    var categories: [Category] = []
    var selectedCategory: Category? = nil {
        didSet {
            // Clear search text when changing categories
            if oldValue?.id != selectedCategory?.id {
                searchText = ""
            }
        }
    }
    
    // Computed Recent category
    var recentCategory: Category {
        Category(id: "recent", name: "Recent", type: .series)
    }
    
    // Computed Favorites categories
    var favoritesLiveCategory: Category {
        Category(id: "fav_live", name: "Favorites (Live)", type: .live)
    }
    
    var favoritesVODCategory: Category {
        Category(id: "fav_vod", name: "Favorites (VOD)", type: .movie)
    }
    
    // All categories including Favorites and Recent
    var allCategories: [Category] {
        [favoritesLiveCategory, favoritesVODCategory, recentCategory] + categories
    }
    var selectedChannel: Channel? {
        didSet {
            print("DEBUG: AppState - selectedChannel changed from \(oldValue?.name ?? "nil") to \(selectedChannel?.name ?? "nil")")
        }
    }
    var searchText: String = ""
    
    // Force UI updates when recent list changes
    private var recentVODUpdateToken: Int = 0
    private var favoritesUpdateToken: Int = 0
    private var cancellables = Set<AnyCancellable>()
    
    // Theme support
    enum AppTheme: String, CaseIterable, Codable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        var id: String { rawValue }
    }
    var theme: AppTheme = .system
    
    // Settings Navigation
    enum SettingsTab: Hashable {
        case general
        case sources
    }
    var settingsTab: SettingsTab = .general
    
    // Playback Signals
    var playPauseSignal: Bool = false
    // toggleFullscreenSignal removed - utilizing NSApp.keyWindow direct toggle
    
    // Runtime state for channel browser (can be toggled independently)
    var isChannelBrowserVisible: Bool = false
    
    // Episode selection state
    var selectedSeriesForEpisodes: Channel?
    var episodesForSeries: [Episode] = []
    var isLoadingEpisodes: Bool = false
    
    init() {
        #if DEBUG
        loadDebugSourceIfAvailable()
        #endif
        
        // Listen for changes in RecentVODManager
        RecentVODManager.shared.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recentVODUpdateToken += 1
                }
            }
            .store(in: &cancellables)
            
        // Listen for changes in FavoritesManager
        FavoritesManager.shared.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.favoritesUpdateToken += 1
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadDebugSourceIfAvailable() {
        let fileManager = FileManager.default
        
        // Try multiple possible locations for debug-config.json
        var possiblePaths: [String] = []
        
        // 1. Check SOURCE_ROOT environment variable (can be set when running)
        if let sourceRoot = ProcessInfo.processInfo.environment["SOURCE_ROOT"] {
            possiblePaths.append("\(sourceRoot)/debug-config.json")
        }
        
        // 2. Current working directory
        possiblePaths.append("\(fileManager.currentDirectoryPath)/debug-config.json")
        
        // 3. Project root (when running from .build)
        possiblePaths.append("\(fileManager.currentDirectoryPath)/../../debug-config.json")
        
        // 4. Hardcoded path (update this to match your project location)
        possiblePaths.append("/Users/inkee/Documents/GitHub/playiptv/debug-config.json")
        
        var debugConfigPath: String?
        for path in possiblePaths {
            let normalizedPath = (path as NSString).standardizingPath
            if fileManager.fileExists(atPath: normalizedPath) {
                debugConfigPath = normalizedPath
                print("DEBUG: Found debug-config.json at: \(normalizedPath)")
                break
            }
        }
        
        guard let configPath = debugConfigPath else {
            print("DEBUG: No debug-config.json found. Checked paths:")
            for path in possiblePaths {
                print("  - \((path as NSString).standardizingPath)")
            }
            return
        }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sourcesArray = json["sources"] as? [[String: String]] else {
            print("DEBUG: Failed to parse debug-config.json at \(configPath)")
            return
        }
        
        print("DEBUG: Loading \(sourcesArray.count) debug source(s) from debug-config.json")
        
        var firstSource: Source?
        
        for sourceDict in sourcesArray {
            guard let name = sourceDict["name"],
                  let typeString = sourceDict["type"] else {
                print("DEBUG: Skipping source with missing name or type")
                continue
            }
            
            let debugSource: Source
            
            if typeString == "xtream" {
                guard let url = sourceDict["xtreamUrl"],
                      let username = sourceDict["username"],
                      let password = sourceDict["password"] else {
                    print("DEBUG: Skipping invalid Xtream source: \(name)")
                    continue
                }
                
                debugSource = Source(
                    name: name,
                    type: .xtream,
                    m3uUrl: nil,
                    xtreamUrl: url,
                    xtreamUser: username,
                    xtreamPass: password
                )
            } else if typeString == "m3u" {
                guard let m3uUrl = sourceDict["m3uUrl"] else {
                    print("DEBUG: Skipping invalid M3U source: \(name)")
                    continue
                }
                
                debugSource = Source(
                    name: name,
                    type: .m3u,
                    m3uUrl: m3uUrl,
                    xtreamUrl: nil,
                    xtreamUser: nil,
                    xtreamPass: nil
                )
            } else {
                print("DEBUG: Unknown source type: \(typeString)")
                continue
            }
            
            print("DEBUG: Adding debug source: \(name) (\(typeString))")
            sources.append(debugSource)
            
            // Track first source
            if firstSource == nil {
                firstSource = debugSource
            }
            
            Task {
                await loadSource(debugSource)
            }
        }
        
        // Set the first source as selected
        if let first = firstSource {
            currentSource = first
            print("DEBUG: Set currentSource to: \(first.name)")
        }
    }
    
    func selectChannel(_ channel: Channel) {
        // Check if this is VOD content (movies only, not live TV or series)
        // A channel is VOD if:
        // 1. It's not a series
        // 2. It's in a Movie category OR doesn't have "Live" in its category/group
        let isMovie = channel.categoryId.lowercased().contains("movie") || 
                      channel.groupTitle?.lowercased().contains("movie") == true
        let isLiveTV = channel.categoryId.lowercased().contains("live") || 
                       channel.groupTitle?.lowercased().contains("live") == true
        
        let isVOD = !channel.isSeries && isMovie && !isLiveTV
        
        print("DEBUG: selectChannel - \(channel.name)")
        print("DEBUG: isSeries: \(channel.isSeries), isMovie: \(isMovie), isLiveTV: \(isLiveTV), isVOD: \(isVOD)")
        
        if isVOD {
            // Check for saved position
            let savedPosition = PlaybackPositionManager.shared.getPosition(streamId: channel.streamId)
            
            // Show unified VOD dialog (with or without resume option)
            vodDialogChannel = channel
            vodDialogSavedPosition = (savedPosition != nil && savedPosition! > 5) ? savedPosition : nil
            showVODDialog = true
        } else {
            // Play directly for live TV and series
            selectedChannel = channel
            handlePlaybackTrigger()
        }
    }
    
    func playVODFromStart() {
        guard let channel = vodDialogChannel else { return }
        if let _ = vodDialogSavedPosition {
            PlaybackPositionManager.shared.clearPosition(streamId: channel.streamId)
        }
        
        // Track in recent VOD (movies only, not series)
        if !channel.isSeries, let sourceUrlString = currentSource?.url?.absoluteString {
            RecentVODManager.shared.addRecentVOD(
                streamId: channel.streamId,
                name: channel.name,
                logoUrl: channel.logoUrl,
                sourceUrl: sourceUrlString,
                isSeries: false
            )
        }
        
        selectedChannel = channel
        showVODDialog = false
        vodDialogChannel = nil
        vodDialogSavedPosition = nil
        playChannel(channel, startPosition: nil)
    }
    
    func resumeVOD() {
        guard let channel = vodDialogChannel,
              let position = vodDialogSavedPosition else { return }
        
        // Track in recent VOD (movies only, not series)
        if !channel.isSeries, let sourceUrlString = currentSource?.url?.absoluteString {
            RecentVODManager.shared.addRecentVOD(
                streamId: channel.streamId,
                name: channel.name,
                logoUrl: channel.logoUrl,
                sourceUrl: sourceUrlString,
                isSeries: false
            )
        }
        
        selectedChannel = channel
        showVODDialog = false
        vodDialogChannel = nil
        vodDialogSavedPosition = nil
        playChannel(channel, startPosition: position)
    }
    
    func cancelVOD() {
        showVODDialog = false
        vodDialogChannel = nil
        vodDialogSavedPosition = nil
    }
    
    var filteredChannels: [Channel] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let channelsToFilter: [Channel]
        
        if let cat = selectedCategory {
            // Check if this is the Recent category
            if cat.id == "recent" {
                // Read token to force update
                let _ = recentVODUpdateToken
                
                // Get recent VOD for current source
                guard let sourceUrl = currentSource?.url else {
                    return []
                }
                let recentItems = RecentVODManager.shared.getRecents(for: sourceUrl.absoluteString)
                channelsToFilter = channels.filter { channel in
                    recentItems.contains { item in
                        // 1. Must match Stream ID
                        guard item.id == channel.streamId else { return false }
                        
                        // 2. Must match Content Type (Series vs Movie)
                        guard item.isSeries == channel.isSeries else { return false }
                        
                        // 3. If it's a movie (isSeries=false), ensure we don't match Live TV with same ID
                        if !item.isSeries {
                            let isLiveTV = channel.categoryId.lowercased().contains("live") || 
                                           channel.groupTitle?.lowercased().contains("live") == true
                            if isLiveTV { return false }
                        }
                        
                        return true
                    }
                }
            } else if cat.id == "fav_live" {
                // Favorites (Live)
                let _ = favoritesUpdateToken
                guard let sourceUrl = currentSource?.url else { return [] }
                
                let favorites = FavoritesManager.shared.getFavorites(for: sourceUrl.absoluteString, type: .live)
                
                // Create lookup map for faster checking
                let favIds = Set(favorites.map { $0.id })
                
                let matchingChannels = channels.filter { channel in
                    // 1. Basic ID check
                    guard favIds.contains(channel.streamId) else { return false }
                    
                    // 2. Strict Type Check
                    if channel.isSeries { return false } // Live is never a series
                    
                    // 3. Heuristic Check
                    let isLiveTV = channel.categoryId.lowercased().contains("live") || 
                                   channel.groupTitle?.lowercased().contains("live") == true
                    return isLiveTV
                }
                
                // Deduplicate by streamId
                var seenIds = Set<String>()
                channelsToFilter = matchingChannels.filter { channel in
                    if seenIds.contains(channel.streamId) { return false }
                    seenIds.insert(channel.streamId)
                    return true
                }
            } else if cat.id == "fav_vod" {
                // Favorites (VOD)
                let _ = favoritesUpdateToken
                guard let sourceUrl = currentSource?.url else { return [] }
                
                let favorites = FavoritesManager.shared.getFavorites(for: sourceUrl.absoluteString, type: .vod)
                
                // Create lookup to check isSeries property
                // Map ID -> isSeries
                var favMap: [String: Bool] = [:]
                for fav in favorites {
                    // Default to matching the channel's type if isSeries is nil (backward compatibility)
                    // But if we have data, use it.
                    if let isSeries = fav.isSeries {
                        favMap[fav.id] = isSeries
                    } else {
                        // Fallback: if not set, we can't strictly filter by it,
                        // so we might still have collision, but we'll try our best in the loop
                        // Use a sentinel? No, just store nothing and handle below.
                        // Ideally we assume false (Movie) or handle ambiguously.
                        // Let's assume we want to match EXACTLY.
                    }
                }
                
                // Also keep a set of IDs for quick existence check
                let favIds = Set(favorites.map { $0.id })

                let matchingChannels = channels.filter { channel in
                    // 1. Basic ID Check
                    guard favIds.contains(channel.streamId) else { return false }
                    
                    // 2. Strict Type Check using saved `isSeries` flag if available
                    // Find the favorite item for this ID
                    if let savedIsSeries = favMap[channel.streamId] {
                        if channel.isSeries != savedIsSeries {
                            return false // ID Match but Type Mismatch -> Collision! Skip this one.
                        }
                    }
                    
                    // 3. General VOD check
                    if channel.isSeries { return true }
                    
                    // If not series, ensure it is NOT Live TV
                    let isLiveTV = channel.categoryId.lowercased().contains("live") || 
                                   channel.groupTitle?.lowercased().contains("live") == true
                    
                    return !isLiveTV
                }
                
                // Deduplicate by streamId
                var seenIds = Set<String>()
                channelsToFilter = matchingChannels.filter { channel in
                    if seenIds.contains(channel.streamId) { return false }
                    seenIds.insert(channel.streamId)
                    return true
                }
            } else {
                channelsToFilter = channels.filter { $0.categoryId == cat.id || $0.groupTitle == cat.name }
            }
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
        // Only set currentSource if it's not already set (prevents race condition)
        if currentSource == nil {
            self.currentSource = source
        }
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
            
            // Create a single "Live TV" category for all M3U content
            let liveCat = Category(id: "live_all", name: "Live TV", type: .live)
            
            // Map all channels to this category
            let unifiedChannels = parsedChannels.map { channel in
                Channel(
                    streamId: channel.streamId,
                    name: channel.name,
                    logoUrl: channel.logoUrl,
                    streamUrl: channel.streamUrl,
                    categoryId: "live_all",
                    groupTitle: channel.groupTitle,
                    isSeries: channel.isSeries
                )
            }
            
            await MainActor.run {
                self.channels = unifiedChannels
                self.categories = [liveCat]
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
            
            // Channels from XtreamClient already have isSeries flag set correctly
            let taggedLive = live.map { let ch = $0; return Channel(streamId: ch.streamId, name: ch.name, logoUrl: ch.logoUrl, streamUrl: ch.streamUrl, categoryId: "live_all", groupTitle: "Live", isSeries: ch.isSeries) }
            let taggedVod = vod.map { let ch = $0; return Channel(streamId: ch.streamId, name: ch.name, logoUrl: ch.logoUrl, streamUrl: ch.streamUrl, categoryId: "vod_all", groupTitle: "Movies", isSeries: ch.isSeries) }
            let taggedSeries = series.map { let ch = $0; return Channel(streamId: ch.streamId, name: ch.name, logoUrl: ch.logoUrl, streamUrl: ch.streamUrl, categoryId: "series_all", groupTitle: "Series", isSeries: ch.isSeries) }
            
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
    
    // Fetch episodes for a series
    func fetchEpisodesForSeries(_ channel: Channel) async {
        guard channel.isSeries,
              let source = currentSource,
              source.type == .xtream,
              let urlStr = source.xtreamUrl,
              let user = source.xtreamUser,
              let pass = source.xtreamPass,
              let client = XtreamClient(url: urlStr, username: user, password: pass) else {
            return
        }
        
        await MainActor.run {
            isLoadingEpisodes = true
            selectedSeriesForEpisodes = channel
        }
        
        do {
            let seriesInfo = try await client.fetchSeriesInfo(seriesId: channel.streamId)
            await MainActor.run {
                episodesForSeries = seriesInfo.episodes
                isLoadingEpisodes = false
            }
        } catch {
            print("ERROR: Failed to fetch episodes: \(error)")
            await MainActor.run {
                episodesForSeries = []
                isLoadingEpisodes = false
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
    
    // MARK: - Player Management
    @MainActor
    private func checkAndStopPlayer() {
        // Log current state for debugging
        print("DEBUG: AppState - Stop check | Selected: \(selectedChannel?.name ?? "nil")")
        
        // Stop the player when no channel is selected
        if selectedChannel == nil {
            print("DEBUG: AppState - ACTION -> Stopping player (No channel selected)")
            PlayerManager.shared.stop()
        } else {
            print("DEBUG: AppState - KEEPING player (Channel active)")
        }
    }
    
    func logout() {
        currentSource = nil
        channels = []
        categories = []
    }
    
    // VOD playback dialog (handles both confirmation and resume)
    var showVODDialog: Bool = false
    var vodDialogChannel: Channel?
    var vodDialogSavedPosition: Double?
    
    // Episode navigation
    var currentSeriesId: String?
    var currentEpisode: Episode?
    var showingEpisodeList: Bool = false
    var episodeListSeries: Channel?
    
    // Get the category that the current episode list series belongs to
    var episodeListParentCategory: Category? {
        guard let series = episodeListSeries else { return nil }
        return categories.first { cat in
            cat.id == series.categoryId || cat.name == series.groupTitle
        }
    }
    
    // MARK: - Playback Authority
    
    private var activeChannel: Channel? {
        selectedChannel
    }
    
    @MainActor
    func handlePlaybackTrigger() {
        if let channel = activeChannel {
            print("DEBUG: AUTHORITY → Firing unified playback for: \(channel.name)")
            // Play directly (VOD dialog is shown in selectChannel)
            playChannel(channel, startPosition: nil)
        } else {
            print("DEBUG: AUTHORITY → All channels cleared. Stopping player.")
            PlayerManager.shared.stop()
        }
    }
    
    func playChannel(_ channel: Channel, startPosition: Double?) {
        PlayerManager.shared.play(
            url: channel.streamUrl,
            streamId: channel.streamId,
            startPosition: startPosition,
            force: false
        )
    }

}
