import SwiftUI

struct FullscreenChannelBrowserView: View {
    @Bindable var appState: AppState
    @Environment(\.openSettings) private var openSettings
    
    var filteredChannels: [Channel] {
        let text = appState.channelSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let channels = appState.filteredChannels
        
        if text.isEmpty {
            return channels
        } else {
            return channels.filter { $0.name.localizedCaseInsensitiveContains(text) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar (Top Right)
            HStack {
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    TextField("Search...", text: $appState.channelSearchText)
                        .textFieldStyle(.plain)
                        .frame(width: 150)
                    if !appState.channelSearchText.isEmpty {
                        Button(action: { appState.channelSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Material.regular)
                .cornerRadius(8)
            }
            .padding(12)
            .background(Material.thick)
            
            Divider()
            
            // Channel List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredChannels) { channel in
                            let isSelected = appState.selectedChannel?.id == channel.id
                            
                            Button(action: {
                                appState.selectChannel(channel)
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "tv")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    
                                    Text(channel.name)
                                        .lineLimit(1)
                                        .foregroundStyle(isSelected ? .white : .primary)
                                    
                                    Spacer()
                                    
                                    if isSelected {
                                        Image(systemName: "play.circle.fill")
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.accentColor : Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(channel.id) // Add ID for scrolling
                            
                            Divider()
                        }
                    }
                }
                .onAppear {
                    // Scroll to selected channel when browser appears (instant, no animation)
                    if let selectedId = appState.selectedChannel?.id {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            proxy.scrollTo(selectedId, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 300)
        .background(Material.thick)
    }
}
