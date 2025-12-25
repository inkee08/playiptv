import SwiftUI

struct ChannelGridView: View {
    @Bindable var appState: AppState
    @Binding var isListView: Bool
    @State private var showEpisodePicker: Bool = false
    @State private var scrollPosition: UUID?
    @State private var scrollToId: UUID?
    @State private var shouldScrollToSelected = false

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    
    private var headerBackgroundColor: Color {
        if isListView {
            return Color(nsColor: .controlBackgroundColor)
        } else {
            return Color(nsColor: .windowBackgroundColor)
        }
    }
    
    private var contentBackgroundColor: Color {
        // Lighter background for content areas (works in light and dark mode)
        Color(nsColor: .textBackgroundColor)
    }
    
    var body: some View {
        Group {
            if appState.showingEpisodeList, let series = appState.episodeListSeries {
                EpisodeListView(
                    appState: appState,
                    series: series,
                    onBack: {
                        appState.showingEpisodeList = false
                        appState.episodeListSeries = nil
                    }
                )
            } else if isListView {
                listView
            } else {
                gridView
            }
        }
        .navigationTitle(appState.showingEpisodeList ? "" : (appState.selectedCategory?.name ?? "All Channels"))
        .searchable(text: $appState.channelSearchText, placement: .toolbar, prompt: "Search channels...")
        .onChange(of: appState.selectedCategory) { oldValue, newValue in
            // Close episode list when category changes OR when clicking the same category
            if appState.showingEpisodeList {
                // Check if user clicked the parent category of the current series
                let clickedParentCategory = (newValue?.id == appState.episodeListParentCategory?.id)
                
                // Close if different category OR if clicking the parent category again
                if oldValue?.id != newValue?.id || clickedParentCategory {
                    appState.showingEpisodeList = false
                    appState.episodeListSeries = nil
                }
            }
        }
    }
    
    private var listView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Show clear button for Recent category
                    if appState.selectedCategory?.id == "recent" && !appState.filteredChannels.isEmpty {
                        Button(action: {
                            RecentVODManager.shared.clearAll()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                                Text("Clear Recent")
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                    
                    
                    ForEach(appState.filteredChannels) { channel in
                        let cacheKey = "\(channel.sourceId.uuidString):\(channel.name)"
                        let cachedProgram = appState.epgProgramCache[cacheKey]
                        
                        let favoriteKey = "\(channel.sourceId.uuidString):\(channel.streamId)"
                        let isFavorited = appState.favoritesCache.contains(favoriteKey)
                        
                        ChannelRowView(
                            channel: channel,
                            epgProgram: cachedProgram,
                            isSelected: appState.selectedChannel?.id == channel.id,
                            isFavorited: isFavorited,
                            onTap: { handleChannelTap(channel) },
                            onToggleFavorite: {
                                if let source = appState.sources.first(where: { $0.id == channel.sourceId }),
                                   let sourceUrl = source.url?.absoluteString {
                                    favoritesManager.toggleFavorite(channel: channel, sourceUrl: sourceUrl)
                                    // Immediately update cache
                                    Task { @MainActor in
                                        appState.updateEPGCache()
                                    }
                                }
                            }
                        )
                        .id(channel.id)
                        
                        Divider()
                    }
                }
            }
            .onChange(of: appState.channelSearchText) { oldValue, newValue in
                // When search is cleared, scroll to selected channel instantly
                if !oldValue.isEmpty && newValue.isEmpty {
                    if let selectedId = appState.selectedChannel?.id {
                        proxy.scrollTo(selectedId, anchor: .center)
                    }
                }
            }
            .onAppear {
                // When list view appears, scroll to selected channel
                if let selectedId = appState.selectedChannel?.id {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(selectedId, anchor: .center)
                    }
                }
            }
            .background(contentBackgroundColor)
        }
    }
    
    private var gridView: some View {
        let columns = [GridItem(.adaptive(minimum: 160), spacing: 20)]
        
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Show clear button for Recent category
                    if appState.selectedCategory?.id == "recent" && !appState.filteredChannels.isEmpty {
                        HStack {
                            Spacer()
                            Button(action: {
                                RecentVODManager.shared.clearAll()
                            }) {
                                Label("Clear Recent", systemImage: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.bordered)
                            .padding()
                        }
                        .background(headerBackgroundColor)
                    }
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(appState.filteredChannels) { channel in
                            channelButton(for: channel)
                                .id(channel.id)
                        }
                    }
                    .padding()
                }
            }
            .onChange(of: appState.channelSearchText) { oldValue, newValue in
                // When search is cleared, scroll to selected channel instantly
                if !oldValue.isEmpty && newValue.isEmpty {
                    if let selectedId = appState.selectedChannel?.id {
                        proxy.scrollTo(selectedId, anchor: .center)
                    }
                }
            }
            .onAppear {
                // When grid view appears, scroll to selected channel
                if let selectedId = appState.selectedChannel?.id {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(selectedId, anchor: .center)
                    }
                }
            }
            .background(contentBackgroundColor)
        }
    }
    
    @ViewBuilder
    func channelButton(for channel: Channel) -> some View {
        let isSelected = appState.selectedChannel?.id == channel.id
        let cacheKey = "\(channel.sourceId.uuidString):\(channel.name)"
        let cachedProgram = appState.epgProgramCache[cacheKey]
        let isLoading = channel.isSeries && appState.isLoadingEpisodes && appState.selectedSeriesForEpisodes?.id == channel.id
        
        Button(action: {
            handleChannelTap(channel)
        }) {
            ChannelCard(
                channel: channel,
                epgProgram: cachedProgram,
                isSelected: isSelected,
                isLoading: isLoading
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let source = appState.sources.first(where: { $0.id == channel.sourceId }),
               let sourceUrl = source.url?.absoluteString {
                let isFavorited = favoritesManager.isFavorite(streamId: channel.streamId, sourceUrl: sourceUrl)
                Button(action: {
                    favoritesManager.toggleFavorite(channel: channel, sourceUrl: sourceUrl)
                }) {
                    Label(isFavorited ? "Remove from Favorites" : "Add to Favorites", 
                          systemImage: isFavorited ? "heart.slash" : "heart")
                }
            }
        }
    }
    
    private func handleChannelTap(_ channel: Channel) {
        if channel.isSeries {
            // Show inline episode list for series
            Task {
                await appState.fetchEpisodesForSeries(channel)
                appState.episodeListSeries = channel
                appState.showingEpisodeList = true
            }
        } else {
            // Direct playback for live TV and movies
            print("DEBUG: Playing channel: \(channel.name)")
            print("DEBUG: Stream URL: \(channel.streamUrl)")
            appState.selectChannel(channel)
        }
    }
}

struct ChannelCard: View, Equatable {
    let channel: Channel
    let epgProgram: EPGProgram?
    let isSelected: Bool
    let isLoading: Bool
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 100)
                .overlay {
                    Image(systemName: "tv")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(20)
                        .foregroundStyle(.secondary)
                }
            
            Text(channel.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Loading indicator for series
            if isLoading {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 10, height: 10)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // EPG Program info (Live TV only)
            if let program = epgProgram {
                Text(program.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(16)
    }
    
    // Equatable conformance - only update if these values change
    static func == (lhs: ChannelCard, rhs: ChannelCard) -> Bool {
        lhs.channel.id == rhs.channel.id &&
        lhs.epgProgram?.id == rhs.epgProgram?.id &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isLoading == rhs.isLoading
    }
}
