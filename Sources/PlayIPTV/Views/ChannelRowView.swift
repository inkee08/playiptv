import SwiftUI

/// Optimized channel row view that leans on Observation for performance
struct ChannelRowView: View {
    let channel: Channel
    let appState: AppState
    let favoritesManager = FavoritesManager.shared
    
    var body: some View {
        let isSelected = appState.selectedChannel?.id == channel.id
        let isLoading = channel.isSeries && appState.isLoadingEpisodes && appState.selectedSeriesForEpisodes?.id == channel.id
        
        // EPG Cache lookup
        let cacheKey = "\(channel.sourceId.uuidString):\(channel.name)"
        let epgProgram = appState.epgProgramCache[cacheKey]
        
        // Favorites check
        let isFavorited: Bool = {
            if let source = appState.sources.first(where: { $0.id == channel.sourceId }),
               let sourceUrl = source.url?.absoluteString {
                return favoritesManager.isFavorite(streamId: channel.streamId, sourceUrl: sourceUrl)
            }
            return false
        }()
        
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "tv")
                    .foregroundStyle(.secondary)
                
                Text(channel.name)
                    .lineLimit(1)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if isFavorited {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                
                Spacer()
            }
            
            // EPG Program info (Live TV only)
            if let program = epgProgram {
                Text(program.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 24)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .onTapGesture {
            if channel.isSeries {
                Task {
                    await appState.fetchEpisodesForSeries(channel)
                    appState.episodeListSeries = channel
                    appState.showingEpisodeList = true
                }
            } else {
                appState.selectChannel(channel)
            }
        }
        .contextMenu {
            if let source = appState.sources.first(where: { $0.id == channel.sourceId }),
               let sourceUrl = source.url?.absoluteString {
                Button(action: {
                    favoritesManager.toggleFavorite(channel: channel, sourceUrl: sourceUrl)
                    Task { @MainActor in
                        appState.updateEPGCache()
                    }
                }) {
                    Label(isFavorited ? "Remove from Favorites" : "Add to Favorites", 
                          systemImage: isFavorited ? "heart.slash" : "heart")
                }
            }
        }
    }
}
