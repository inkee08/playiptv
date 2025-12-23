import SwiftUI

struct ContentView: View {
    var appState: AppState
    
    var body: some View {
        Group {
            if appState.currentSource == nil {
                SettingsView(appState: appState)
                    .frame(minWidth: 500, minHeight: 400)
            } else {
                NavigationSplitView {
                    SidebarView(appState: appState)
                } content: {
                    ChannelGridView(appState: appState)
                } detail: {
                    if let channel = appState.selectedChannel {
                        PlayerView(url: channel.streamUrl)
                    } else {
                        Text("Select a channel to play")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
