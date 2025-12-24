import SwiftUI
import Combine

@Observable
@MainActor
class AppState {
    // Data per source
    struct SourceContent {
        var channels: [Channel] = []
        var categories: [Category] = []
    }
    
    // Storage for all loaded sources
    var sourceContent: [UUID: SourceContent] = [:]
    
    // Track loading state per source
    var loadingSources: Set<UUID> = []
    
    // UI ticker for periodic updates (e.g. EPG program boundaries)
    // UI ticker for periodic updates (e.g. EPG program boundaries)
    var currentTick: Int = 0
    
    var selectedSource: Source? {
        didSet {
            // clear selection when switching sources
            if oldValue?.id != selectedSource?.id {
                selectedCategory = nil
                searchText = ""
                
                // Persist selection
                if let id = selectedSource?.id.uuidString {
                    UserDefaults.standard.set(id, forKey: "lastSourceId")
                } else {
                    UserDefaults.standard.removeObject(forKey: "lastSourceId")
                }
                
                // Auto-select first Live TV category for new source
                if let source = selectedSource, let content = sourceContent[source.id] {
                    if let liveCategory = content.categories.first(where: { $0.type == .live }) {
                        selectedCategory = liveCategory
                        print("DEBUG: Auto-selected Live TV category: \(liveCategory.name)")
                    }
                }
            }
        }
    }
    
    // Computed properties for UI compatibility
    // These return content for the CURRENTLY SELECTED source
    var channels: [Channel] {
        guard let source = selectedSource, let content = sourceContent[source.id] else { return [] }
        return content.channels
    }
    
    var categories: [Category] {
        guard let source = selectedSource, let content = sourceContent[source.id] else { return [] }
        return content.categories
    }
    
    var selectedCategory: Category? = nil {
        didSet {
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
    var theme: AppTheme = .system {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
        }
    }
    
    // EPG support
    var epgUrl: String? {
        didSet {
            if let url = epgUrl {
                UserDefaults.standard.set(url, forKey: "epgUrl")
            } else {
                UserDefaults.standard.removeObject(forKey: "epgUrl")
            }
        }
    }
    var lastEPGUpdate: Date?
    
    enum EPGRefreshInterval: String, CaseIterable, Codable, Identifiable {
        case manual = "Manual"
        case twelveHours = "Every 12 Hours"
        case twentyFourHours = "Every 24 Hours"
        
        var id: String { rawValue }
        
        var seconds: TimeInterval? {
            switch self {
            case .manual: return nil
            case .twelveHours: return 12 * 3600
            case .twentyFourHours: return 24 * 3600
            }
        }
    }
    
    var epgRefreshInterval: EPGRefreshInterval = .twentyFourHours {
        didSet {
            UserDefaults.standard.set(epgRefreshInterval.rawValue, forKey: "epgRefreshInterval")
        }
    }
    
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
    var channelSearchText: String = "" // Shared search text for channel filtering
    
    // Episode selection state
    var selectedSeriesForEpisodes: Channel?
    var episodesForSeries: [Episode] = []
    var isLoadingEpisodes: Bool = false
    
    init() {
        // Load Theme
        if let savedTheme = UserDefaults.standard.string(forKey: "appTheme"),
           let loadedTheme = AppTheme(rawValue: savedTheme) {
            self.theme = loadedTheme
        }
        
        // Load Sources
        if let data = UserDefaults.standard.data(forKey: "savedSources"),
           let loadedSources = try? JSONDecoder().decode([Source].self, from: data) {
            self.sources = loadedSources
        }
        
        // Load EPG URL
        self.epgUrl = UserDefaults.standard.string(forKey: "epgUrl")
        
        // Load EPG refresh interval
        if let savedInterval = UserDefaults.standard.string(forKey: "epgRefreshInterval"),
           let interval = EPGRefreshInterval(rawValue: savedInterval) {
            self.epgRefreshInterval = interval
        }
        
        #if DEBUG
        loadDebugSourceIfAvailable()
        #endif
        
        // Load content for all sources
        Task {
            await loadAllSources()
            
            // Restore selection AFTER loading (or concurrent with it)
            if selectedSource == nil {
                if let lastId = UserDefaults.standard.string(forKey: "lastSourceId"),
                   let source = sources.first(where: { $0.id.uuidString == lastId }) {
                    await MainActor.run { selectedSource = source }
                } else if let first = sources.first {
                    // Fallback to first source
                    await MainActor.run { selectedSource = first }
                }
            }
            
            // Load global EPG if configured
            if let epgUrl = epgUrl, !epgUrl.isEmpty {
                await EPGManager.shared.loadGlobalEPG(from: epgUrl)
                await MainActor.run {
                    lastEPGUpdate = EPGManager.shared.lastUpdateTime
                }
            }
            
            // Load per-source EPG for each source
            for source in sources {
                if let sourceEpg = source.epgUrl, !sourceEpg.isEmpty {
                    await EPGManager.shared.loadEPG(for: source.id, from: sourceEpg)
                }
            }
            
            // Set up EPG auto-refresh timer
            // Set up EPG auto-refresh timer
            setupEPGAutoRefresh()
            
            // Set up UI refresh timer (every minute) to update "Current Program" displays
            setupUIRefreshTimer()
        }
        
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
        
        // Load global EPG URL if present
        if let globalEpg = json["globalEpgUrl"] as? String {
            self.epgUrl = globalEpg
            print("DEBUG: Loaded global EPG URL: \(globalEpg)")
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
                    xtreamPass: password,
                    epgUrl: sourceDict["epgUrl"]
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
                    xtreamPass: nil,
                    epgUrl: sourceDict["epgUrl"]
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
        
        // Now load all sources (persisted + debug)
        Task {
            // Set the first debug source as selected if no other source was selected from persistence
            if selectedSource == nil, let first = firstSource {
                await MainActor.run {
                    selectedSource = first
                    print("DEBUG: Set selectedSource to first debug source: \(first.name)")
                }
            }
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
        if !channel.isSeries,
           let source = sources.first(where: { $0.id == channel.sourceId }),
           let sourceUrlString = source.url?.absoluteString {
               
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
        if !channel.isSeries,
           let source = sources.first(where: { $0.id == channel.sourceId }),
           let sourceUrlString = source.url?.absoluteString {
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
        let text = channelSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var channelsToFilter: [Channel]
        
        if let cat = selectedCategory {
            // Check if this is the Recent category
            if cat.id == "recent" {
                // Read token to force update
                let _ = recentVODUpdateToken
                
                // Get recent VOD for current source
                guard let source = selectedSource, let sourceUrl = source.url, let content = sourceContent[source.id] else {
                    return []
                }
                let recentItems = RecentVODManager.shared.getRecents(for: sourceUrl.absoluteString)
                channelsToFilter = content.channels.filter { channel in
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
                guard let source = selectedSource, let sourceUrl = source.url, let content = sourceContent[source.id] else { return [] }
                
                let favorites = FavoritesManager.shared.getFavorites(for: sourceUrl.absoluteString, type: .live)
                
                // Filter content using the content we just guarded
                channelsToFilter = content.channels.filter { channel in
                    favorites.contains(where: { $0.id == channel.streamId })
                }
                
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
                guard let source = selectedSource, let sourceUrl = source.url, let content = sourceContent[source.id] else { return [] }
                
                let favorites = FavoritesManager.shared.getFavorites(for: sourceUrl.absoluteString, type: .vod)
                
                // Filter content using the content we just guarded
                channelsToFilter = content.channels.filter { channel in
                    favorites.contains(where: { $0.id == channel.streamId })
                }
                
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
                guard let source = selectedSource, let content = sourceContent[source.id] else { return [] }
                channelsToFilter = content.channels.filter { $0.categoryId == cat.id || $0.groupTitle == cat.name }
            }
        } else {
            guard let source = selectedSource, let content = sourceContent[source.id] else { return [] }
            channelsToFilter = content.channels
        }
        
        if text.isEmpty {
            return channelsToFilter
        } else {
            return channelsToFilter.filter { channel in
                // 1. Check channel name
                if channel.name.localizedCaseInsensitiveContains(text) {
                    return true
                }
                
                // 2. Check current program title from EPG
                if let program = EPGManager.shared.getCurrentProgram(for: channel.name, sourceId: channel.sourceId),
                   program.title.localizedCaseInsensitiveContains(text) {
                    return true
                }
                
                return false
            }
        }
    }
    
    var isLoading: Bool = false
    var errorMessage: String?
    
    // Multi-source management
    var sources: [Source] = []
    
    func loadAllSources() async {
        print("DEBUG: Loading all sources...")
        await MainActor.run {
            loadingSources = Set(sources.map { $0.id })
            
            // Set initial selected source if needed (logic moved to init Task, but good to keep safe)
            if selectedSource == nil && !sources.isEmpty {
                // Only set if not already set by init logic
                 // selectedSource = sources.first // Let init handle this to prefer saved source
            }
        }
        
        await withTaskGroup(of: Void.self) { group in
            for source in sources {
                group.addTask {
                    await self.loadSource(source)
                }
            }
        }
    }
    
    // Load Specific Source
    func loadSource(_ source: Source) async {
        print("DEBUG: Loading source: \(source.name)")
        
        _ = await MainActor.run { loadingSources.insert(source.id) }
        
        let newContent: SourceContent
        
        switch source.type {
        case .m3u:
            newContent = await loadM3U(source: source)
        case .xtream:
            newContent = await loadXtream(source: source)
        }
        
        await MainActor.run {
            sourceContent[source.id] = newContent
            loadingSources.remove(source.id)
            print("DEBUG: Loaded \(newContent.channels.count) channels for \(source.name)")
            
            // Set default selected category to first Live TV category if none selected
            if selectedCategory == nil {
                if let liveCategory = newContent.categories.first(where: { $0.type == .live }) {
                    selectedCategory = liveCategory
                    print("DEBUG: Set default category to: \(liveCategory.name)")
                }
            }
        }
    }
    
    // Load M3U
    // Load M3U
    private func loadM3U(source: Source) async -> SourceContent {
        guard let urlStr = source.m3uUrl, let url = URL(string: urlStr) else {
            await MainActor.run { errorMessage = "Invalid M3U URL for \(source.name)" }
            return SourceContent()
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
                    sourceId: source.id,
                    streamId: channel.streamId,
                    name: channel.name,
                    logoUrl: channel.logoUrl,
                    streamUrl: channel.streamUrl,
                    categoryId: "live_all",
                    groupTitle: channel.groupTitle,
                    isSeries: channel.isSeries
                )
            }
            
            return SourceContent(channels: unifiedChannels, categories: [liveCat])
            
        } catch {
            print("ERROR: M3U Load failed for \(source.name): \(error)")
            await MainActor.run { errorMessage = error.localizedDescription }
            return SourceContent()
        }
    }
    
    // Load Xtream
    private func loadXtream(source: Source) async -> SourceContent {
        guard let urlStr = source.xtreamUrl,
              let user = source.xtreamUser,
              let pass = source.xtreamPass,
              let client = XtreamClient(url: urlStr, username: user, password: pass) else {
            await MainActor.run { errorMessage = "Invalid Credentials for \(source.name)" }
            return SourceContent()
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
            let taggedLive = live.map { let ch = $0; return Channel(sourceId: source.id, streamId: ch.streamId, name: ch.name, logoUrl: ch.logoUrl, streamUrl: ch.streamUrl, categoryId: "live_all", groupTitle: "Live", isSeries: ch.isSeries) }
            let taggedVod = vod.map { let ch = $0; return Channel(sourceId: source.id, streamId: ch.streamId, name: ch.name, logoUrl: ch.logoUrl, streamUrl: ch.streamUrl, categoryId: "vod_all", groupTitle: "Movies", isSeries: ch.isSeries) }
            let taggedSeries = series.map { let ch = $0; return Channel(sourceId: source.id, streamId: ch.streamId, name: ch.name, logoUrl: ch.logoUrl, streamUrl: ch.streamUrl, categoryId: "series_all", groupTitle: "Series", isSeries: ch.isSeries) }
            
            return SourceContent(channels: taggedLive + taggedVod + taggedSeries, categories: [liveCat, movieCat, seriesCat])
            
        } catch {
            print("ERROR: Xtream Load failed for \(source.name): \(error)")
            await MainActor.run { errorMessage = error.localizedDescription }
            return SourceContent()
        }
    }
    
    // Fetch episodes for a series
    func fetchEpisodesForSeries(_ channel: Channel) async {
        guard channel.isSeries,
              let source = sources.first(where: { $0.id == channel.sourceId }),
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
        saveSources()
        Task {
            await loadSource(source)
            if selectedSource == nil {
                selectedSource = source
            }
        }
    }
    
    func removeSource(_ source: Source) {
        sources.removeAll { $0.id == source.id }
        saveSources()
        sourceContent.removeValue(forKey: source.id)
        if selectedSource?.id == source.id {
            selectedSource = nil
            selectedCategory = nil
            
            // Try to select another source
            if let first = sources.first {
                selectedSource = first
            }
        }
    }
    
    private func saveSources() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: "savedSources")
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
        selectedSource = nil
        selectedCategory = nil
        // Optional: clear persistence or keep loaded?
        // User said "logout", usually implies clearing viewing state.
        // Data stays loaded.
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
    
    // MARK: - EPG Auto-Refresh
    
    private func setupEPGAutoRefresh() {
        // Check every hour if EPG needs refreshing
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAndRefreshEPG()
            }
        }
    }
    
    private func checkAndRefreshEPG() async {
        let now = Date()
        
        // Check global EPG (uses global interval setting)
        if let epgUrl = epgUrl, !epgUrl.isEmpty, let interval = epgRefreshInterval.seconds {
            if let lastUpdate = lastEPGUpdate {
                let timeSinceUpdate = now.timeIntervalSince(lastUpdate)
                if timeSinceUpdate >= interval {
                    print("DEBUG: EPG → Auto-refreshing global EPG")
                    await EPGManager.shared.loadGlobalEPG(from: epgUrl)
                    lastEPGUpdate = EPGManager.shared.lastUpdateTime
                }
            }
        }
    
        // Check per-source EPG (uses per-source interval setting)
        for source in sources {
            if let sourceEpg = source.epgUrl, !sourceEpg.isEmpty {
                // Get source-specific interval or default to 24 hours
                let intervalString = source.epgRefreshInterval ?? EPGRefreshInterval.twentyFourHours.rawValue
                guard let sourceInterval = EPGRefreshInterval(rawValue: intervalString),
                      let seconds = sourceInterval.seconds else {
                    continue // Skip if manual refresh
                }
                
                if let lastUpdate = EPGManager.shared.sourceUpdateTimes[source.id] {
                    let timeSinceUpdate = now.timeIntervalSince(lastUpdate)
                    if timeSinceUpdate >= seconds {
                        print("DEBUG: EPG → Auto-refreshing EPG for source \(source.name)")
                        await EPGManager.shared.loadEPG(for: source.id, from: sourceEpg)
                    }
                }
            }
        }
    }
    
    // MARK: - UI Auto-Refresh
    
    private func setupUIRefreshTimer() {
        // Update UI every 30 seconds to reflect program changes
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentTick += 1
            }
        }
    }

}
