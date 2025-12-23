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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.name)
                                    .font(.headline)
                                Text(source.type == .m3u ? "M3U Playlist" : "Xtream Codes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                // Show summary if this is the current source
                                if appState.currentSource?.id == source.id {
                                    HStack(spacing: 12) {
                                        Label("\(appState.categories.count)", systemImage: "folder")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Label("\(appState.channels.count)", systemImage: "tv")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.top, 2)
                                }
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
    @Bindable var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = "My Playlist"
    @State private var sourceType: StreamType = .m3u
    @State private var m3uUrl: String = ""
    @State private var xtreamUrl: String = ""
    @State private var xtreamUsername: String = ""
    @State private var xtreamPassword: String = ""
    @FocusState private var isNameFieldFocused: Bool
    @State private var validationError: String?
    
    var body: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("", text: $name)
                    .focused($isNameFieldFocused)
            }
            
            Picker("", selection: $sourceType) {
                Text("M3U Playlist").tag(StreamType.m3u)
                Text("Xtream Codes").tag(StreamType.xtream)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            
            if sourceType == .m3u {
                VStack(alignment: .leading, spacing: 4) {
                    Text("M3U URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("", text: $m3uUrl)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("", text: $xtreamUrl)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("", text: $xtreamUsername)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("", text: $xtreamPassword)
                }
            }
            
            if let error = validationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    if validateAndAdd() {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(12)
        .frame(width: 400, height: sourceType == .m3u ? 200 : 310)
        .onAppear {
            isNameFieldFocused = true
        }
    }
    
    private func validateAndAdd() -> Bool {
        validationError = nil
        
        // Validate name
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "Name is required"
            return false
        }
        
        if sourceType == .m3u {
            // Validate M3U URL
            guard !m3uUrl.trimmingCharacters(in: .whitespaces).isEmpty else {
                validationError = "M3U URL is required"
                return false
            }
            
            guard let url = URL(string: m3uUrl.trimmingCharacters(in: .whitespaces)),
                  url.scheme != nil else {
                validationError = "Invalid M3U URL format"
                return false
            }
            
            let source = Source(
                name: name.trimmingCharacters(in: .whitespaces),
                type: .m3u,
                m3uUrl: m3uUrl.trimmingCharacters(in: .whitespaces)
            )
            appState.addSource(source)
        } else {
            // Validate Xtream fields
            guard !xtreamUrl.trimmingCharacters(in: .whitespaces).isEmpty else {
                validationError = "Server URL is required"
                return false
            }
            
            guard let url = URL(string: xtreamUrl.trimmingCharacters(in: .whitespaces)),
                  url.scheme != nil else {
                validationError = "Invalid Server URL format"
                return false
            }
            
            guard !xtreamUsername.trimmingCharacters(in: .whitespaces).isEmpty else {
                validationError = "Username is required"
                return false
            }
            
            guard !xtreamPassword.isEmpty else {
                validationError = "Password is required"
                return false
            }
            
            let source = Source(
                name: name.trimmingCharacters(in: .whitespaces),
                type: .xtream,
                xtreamUrl: xtreamUrl.trimmingCharacters(in: .whitespaces),
                xtreamUser: xtreamUsername.trimmingCharacters(in: .whitespaces),
                xtreamPass: xtreamPassword
            )
            appState.addSource(source)
        }
        
        return true
    }
}
