import SwiftUI

struct SidebarView: View {
    @Bindable var appState: AppState
    
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        List(selection: $appState.selectedCategory) {
            
            Section("Library") {
                // Favorites categories
                NavigationLink(value: appState.favoritesLiveCategory) {
                    Label("Favorites (Live)", systemImage: "heart.fill")
                        .foregroundStyle(.pink)
                }
                
                // Show VOD items only for non-M3U sources (typically Xtream)
                if appState.selectedSource?.type != .m3u {
                    NavigationLink(value: appState.favoritesVODCategory) {
                        Label("Favorites (VOD)", systemImage: "heart.fill")
                            .foregroundStyle(.purple)
                    }
                    
                    // Recent category
                    NavigationLink(value: appState.recentCategory) {
                        Label("Recent", systemImage: "clock")
                    }
                }
            }
            
            Section("Categories") {
                ForEach(appState.categories) { category in
                    NavigationLink(value: category) {
                        Label(category.name, systemImage: iconFor(category.type))
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        .listStyle(.sidebar)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            // Try principal or primaryAction to see if it moves it correctly on macOS
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                }) {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")
            }
        }
    }
    
    private func iconFor(_ type: CategoryType) -> String {
        switch type {
        case .live: return "tv"
        case .movie: return "film"
        case .series: return "play.tv"
        }
    }
}
