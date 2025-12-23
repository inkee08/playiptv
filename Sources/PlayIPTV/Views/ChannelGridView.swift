import SwiftUI

struct ChannelGridView: View {
    var appState: AppState
    
    // View Mode State
    @State private var isListView: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openSettings) private var openSettings
    
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
                        appState.selectedChannel = channel
                    }
                    .listRowBackground(appState.selectedChannel?.id == channel.id ? Color.accentColor.opacity(0.2) : nil)
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
        .padding(.top, 0) // Explicitly handle safe area if needed, but let's try safeAreaInset first if pure padding fails.
        // Actually, with hiddenTitleBar, the safe area might be ignored by ScrollView default.
        // Adding a safeAreaInset or explicit padding is safer.
        .safeAreaInset(edge: .top) {
            Rectangle()
                .fill(headerBackgroundColor)
                .frame(height: 40)
                .ignoresSafeArea()
        }
        .navigationTitle(appState.selectedCategory?.name ?? "All Channels")
        .searchable(text: Bindable(appState).searchText)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("View Mode", selection: $isListView) {
                    Label("Grid", systemImage: "square.grid.2x2").tag(false)
                    Label("List", systemImage: "list.bullet").tag(true)
                }
                .pickerStyle(.inline)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task { try? await openSettings() }
                }) {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
    }
    
    @ViewBuilder
    func channelButton(for channel: Channel) -> some View {
        let isSelected = appState.selectedChannel?.id == channel.id
        Button(action: {
            appState.selectedChannel = channel
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
