import SwiftUI

struct ChannelGridView: View {
    var appState: AppState
    
    // View Mode State
    // View Mode State - Now passed from ContentView
    @Binding var isListView: Bool

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    
    private var headerBackgroundColor: Color {
        // We use semantic colors which will match the FORCED color scheme environment
        if isListView {
            return Color(nsColor: .controlBackgroundColor)
        } else {
            return Color(nsColor: .windowBackgroundColor)
        }
    }
    
    var body: some View {
        Group {
            if isListView {
                List(appState.filteredChannels) { channel in
                    HStack {
                        if let _ = channel.logoUrl {
                             Image(systemName: "tv") // Placeholder
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "tv")
                                .foregroundStyle(.secondary)
                        }
                        Text(channel.name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.selectChannel(channel)
                        if appState.playerMode == .detached {
                            // openWindow(id: "playerWindow")
                            DetachedWindowManager.shared.open(appState: appState)
                        }
                    }
                    .listRowBackground((appState.selectedChannel?.id == channel.id || appState.detachedChannel?.id == channel.id) ? Color.accentColor.opacity(0.2) : nil)
                }
            } else {
                let columns = [GridItem(.adaptive(minimum: 160), spacing: 20)]
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(appState.filteredChannels) { channel in
                            channelButton(for: channel)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(appState.selectedCategory?.name ?? "All Channels")
    }
    
    @ViewBuilder
    func channelButton(for channel: Channel) -> some View {
        let isSelected = appState.selectedChannel?.id == channel.id || appState.detachedChannel?.id == channel.id
        Button(action: {
            appState.selectChannel(channel)
            if appState.playerMode == .detached {
                // openWindow(id: "playerWindow")
                DetachedWindowManager.shared.open(appState: appState)
            }
        }) {
            ChannelCard(channel: channel, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct ChannelCard: View {
    let channel: Channel
    let isSelected: Bool
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 100)
                .overlay {
                    if let _ = channel.logoUrl {
                        Image(systemName: "tv")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(20)
                    } else {
                        Image(systemName: "tv")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(20)
                            .foregroundStyle(.secondary)
                    }
                }
            
            Text(channel.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(16)
    }
}
