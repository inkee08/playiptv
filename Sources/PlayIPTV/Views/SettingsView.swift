import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.settingsTab) {
            GeneralSettingsView(appState: appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(AppState.SettingsTab.general)
            
            SourceSettingsView(appState: appState)
                .tabItem {
                    Label("Sources", systemImage: "server.rack")
                }
                .tag(AppState.SettingsTab.sources)
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @Bindable var appState: AppState
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Label("Appearance", systemImage: "paintpalette")) {
                VStack(alignment: .leading) {
                    Picker("Theme", selection: $appState.theme) {
                        ForEach(AppState.AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding()
            }
            
            GroupBox(label: Label("Playback", systemImage: "play.rectangle")) {
                VStack(alignment: .leading) {
                    Picker("Player Mode", selection: $appState.playerMode) {
                        ForEach(AppState.PlayerMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: appState.playerMode) { oldMode, newMode in
                        // Transfer channel when switching modes
                        appState.switchPlayerMode(to: newMode)
                    }
                    
                    Text(appState.playerMode == .attached ? "Video plays inside the main window." : "Video opens in a separate window.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}

struct SourceSettingsView: View {
    @Bindable var appState: AppState
    @State private var showingAddSource = false
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                if !appState.sources.isEmpty {
                    ForEach(appState.sources) { source in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(source.name)
                                    .font(.headline)
                                Text(source.type == .m3u ? "M3U Playlist" : "Xtream Codes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if appState.currentSource?.id == source.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Button("Load") {
                                    Task {
                                        await appState.loadSource(source)
                                    }
                                }
                            }
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                appState.removeSource(source)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            appState.removeSource(appState.sources[index])
                        }
                    }
                }
            }
            .overlay {
                if appState.sources.isEmpty {
                    ContentUnavailableView("No Sources", systemImage: "tv.slash", description: Text("Add an IPTV source to get started."))
                }
            }
            // Footer Bar
            HStack {
                Button(action: { showingAddSource = true }) {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("\(appState.sources.count) sources")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Placeholder for symmetry or Delete button if we added selection state to the list
                Color.clear.frame(width: 20, height: 20)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Material.bar)
            
            Divider()
        }
        .sheet(isPresented: $showingAddSource) {
            AddSourceView(appState: appState)
                .frame(width: 400, height: 350)
        }
    }
}

struct AddSourceView: View {
    var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = "My Playlist"
    @State private var type: StreamType = .m3u
    
    // M3U
    @State private var m3uUrl: String = ""
    
    // Xtream
    @State private var xtreamUrl: String = ""
    @State private var xtreamUser: String = ""
    @State private var xtreamPass: String = ""
    
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                    .focused($isNameFieldFocused)
                Picker("Type", selection: $type) {
                    Text("M3U Playlist").tag(StreamType.m3u)
                    Text("Xtream Codes").tag(StreamType.xtream)
                }
                .pickerStyle(.segmented)
            }
            
            Section("Configuration") {
                if type == .m3u {
                    TextField("M3U URL", text: $m3uUrl)
                        .onSubmit { addNewSource() }
                } else {
                    TextField("Server URL", text: $xtreamUrl)
                        .onSubmit { addNewSource() }
                    TextField("Username", text: $xtreamUser)
                        .onSubmit { addNewSource() }
                    SecureField("Password", text: $xtreamPass)
                        .onSubmit { addNewSource() }
                }
            }
            
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Spacer()
                Button("Add Source") {
                    addNewSource()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
            .padding(.top)
        }
        .padding()
    }
    
    private func addNewSource() {
        guard !name.isEmpty else { return }
        
        let source = Source(
            name: name,
            type: type,
            m3uUrl: type == .m3u ? m3uUrl : nil,
            xtreamUrl: type == .xtream ? xtreamUrl : nil,
            xtreamUser: type == .xtream ? xtreamUser : nil,
            xtreamPass: type == .xtream ? xtreamPass : nil
        )
        appState.addSource(source)
        dismiss()
    }
}
