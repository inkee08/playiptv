import SwiftUI

struct ContentView: View {
    var appState: AppState
    
    var body: some View {
        Group {
            if appState.currentSource == nil {
                WelcomeView(appState: appState)
                    .frame(minWidth: 600, minHeight: 400)
            } else {
                NavigationSplitView {
                    SidebarView(appState: appState)
                } content: {
                    ChannelGridView(appState: appState)
                } detail: {
                    if let channel = appState.selectedChannel {
                        ZStack(alignment: .topTrailing) {
                            PlayerView(url: channel.streamUrl)
                            
                            Button(action: {
                                appState.selectedChannel = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .background(Circle().fill(Color.black.opacity(0.4)))
                            }
                            .buttonStyle(.plain)
                            .padding(20)
                        }
                    } else {
                        ContentUnavailableView("Select a Channel", systemImage: "tv", description: Text("Choose a channel from the list to start watching."))
                    }
                }
            }
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
                Task { try? await openSettings() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(50)
    }
}
