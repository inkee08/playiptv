import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    
    @FocusState private var isPlayerFocused: Bool
    @State private var isFullscreen: Bool = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var detachedColumnVisibility = NavigationSplitViewVisibility.all
    @State private var isListView: Bool = true
    
    var body: some View {
        Group {
            if appState.currentSource == nil {
                WelcomeView(appState: appState)
                    .frame(minWidth: 600, minHeight: 400)
            } else {
                mainContent
            }
        }
        .toolbar {
            AppToolbar(
                appState: appState,
                isListView: $isListView,
                onToggleSidebar: toggleSidebar,
                onOpenSettings: { openSettings() }
            )
        }
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbarBackground(Color(nsColor: .windowBackgroundColor), for: .windowToolbar)
        // Hide toolbar in fullscreen
        .toolbar(isFullscreen ? .hidden : .visible, for: .windowToolbar)
        .handleWindowFullscreen(isFullscreen: $isFullscreen)
        .sheet(isPresented: $appState.showVODDialog) {
            if let channel = appState.vodDialogChannel {
                VODPlaybackDialog(
                    channel: channel,
                    savedPosition: appState.vodDialogSavedPosition,
                    onPlay: {
                        appState.playVODFromStart()
                    },
                    onResume: appState.vodDialogSavedPosition != nil ? {
                        appState.resumeVOD()
                    } : nil,
                    onCancel: {
                        appState.cancelVOD()
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if isFullscreen, let channel = appState.selectedChannel {
            fullscreenPlayer(channel: channel)
        } else {
            attachedSplitView
        }
    }
    
    // Stable player view that persists across mode changes
    private var playerView: some View {
        PlayerView()
            .id("stable-player-view") // Prevent recreation
            .focused($isPlayerFocused)
    }
    
    private var attachedSplitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(appState: appState)
        } content: {
            ChannelGridView(appState: appState, isListView: $isListView)
        } detail: {
            ZStack {
                if let channel = appState.selectedChannel {
                    playerDetailView(channel: channel)
                } else {
                    ContentUnavailableView("Select a Channel", systemImage: "tv", description: Text("Choose a channel from the list to start watching."))
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    private var detachedSplitView: some View {
        NavigationSplitView(columnVisibility: $detachedColumnVisibility) {
            SidebarView(appState: appState)
                .toolbar(removing: .sidebarToggle)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button(action: toggleSidebar) {
                            Image(systemName: "sidebar.left")
                        }
                        .help("Toggle Sidebar")
                    }
                }
        } detail: {
            ChannelGridView(appState: appState, isListView: $isListView)
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    private func fullscreenPlayer(channel: Channel) -> some View {
        ZStack(alignment: .topLeading) {
            // Main content
            HStack(spacing: 0) {
                // Channel Browser (Leading)
                if appState.isChannelBrowserVisible {
                    FullscreenChannelBrowserView(appState: appState)
                        .frame(width: 320)
                        .transition(.move(edge: .leading))
                }
                
                // Video Player
                playerView
                    .onAppear {
                        isPlayerFocused = true
                        // Initialize browser visibility - start hidden
                        appState.isChannelBrowserVisible = false
                    }
            }
            
            // Toggle button - on top of everything
            Button(action: {
                withAnimation {
                    appState.isChannelBrowserVisible.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.8))
                        .frame(width: 44, height: 44)
                    
                    Text(appState.isChannelBrowserVisible ? "◀" : "▶")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .help(appState.isChannelBrowserVisible ? "Hide Channels" : "Show Channels")
            .padding(.leading, appState.isChannelBrowserVisible ? 340 : 20)
            .padding(.top, 20)
        }
        .ignoresSafeArea()
    }
    
    private func playerDetailView(channel: Channel) -> some View {
        ZStack(alignment: .topTrailing) {
            playerView
                .onAppear {
                    isPlayerFocused = true
                }
            
            // Overlay buttons (hidden in fullscreen)
            if !isFullscreen {
                HStack(spacing: 15) {
                    Button(action: {
                        NSApp.keyWindow?.toggleFullScreen(nil)
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.8))
                            .background(Circle().fill(Color.black.opacity(0.4)).frame(width: 36, height: 36))
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Fullscreen")
                    
                    Button(action: {
                        appState.selectedChannel = nil
                        // Also explicitly stop the manager
                        PlayerManager.shared.stop()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.8))
                            .background(Circle().fill(Color.black.opacity(0.4)))
                    }
                    .buttonStyle(.plain)
                    .help("Stop Playback")
                }
                .padding(20)
            }
        }
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

// MARK: - Independent Toolbar Component
struct AppToolbar: ToolbarContent {
    var appState: AppState
    @Binding var isListView: Bool
    var onToggleSidebar: () -> Void
    var onOpenSettings: () -> Void
    
    var body: some ToolbarContent {
        // Right Actions (Fixed to Right via Spacer)
        ToolbarItemGroup(placement: .automatic) {
            Spacer() // Push everything to the trailing edge
            
            // 2. Right Actions
            // Source Picker
            Menu {
                Picker("Source", selection: Bindable(appState).currentSource) {
                    ForEach(appState.sources) { source in
                        Text(source.name).tag(Optional(source))
                    }
                }
                .pickerStyle(.inline)
                
                Divider()
                
                Button("Manage Sources...") {
                    appState.settingsTab = .sources
                    onOpenSettings()
                }
            } label: {
                Label("Sources", systemImage: "server.rack")
            }
            
            // View Mode
            Picker("View Mode", selection: $isListView) {
                Label("Grid", systemImage: "square.grid.2x2").tag(false)
                Label("List", systemImage: "list.bullet").tag(true)
            }
            .pickerStyle(.inline)
            
            // Settings
            Button(action: {
                onOpenSettings()
            }) {
                Label("Settings", systemImage: "gear")
            }
            
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search...", text: Bindable(appState).searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 180)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Material.regular)
            .cornerRadius(6)
        }
    }
}

struct WelcomeView: View {
    var appState: AppState
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "tv.inset.filled")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(.tint)
            
            VStack(spacing: 10) {
                Text("Welcome to PlayIPTV")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Watch your favorite live TV, movies, and series\nfrom your Xtream or M3U providers.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Add Source") {
                appState.settingsTab = .sources
                openSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(50)
    }
}
