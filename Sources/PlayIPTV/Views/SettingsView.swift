import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    
    @State private var showingAddSource = false
    
    var body: some View {
        NavigationStack {
            List {
                if appState.sources.isEmpty {
                    ContentUnavailableView("No Sources", systemImage: "tv.slash", description: Text("Add an IPTV source to get started."))
                } else {
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
                                Button("Select") {
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
            .navigationTitle("Sources")
            
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appState.theme) {
                        ForEach(AppState.AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding()
            .toolbar {
                Button(action: { showingAddSource = true }) {
                    Label("Add Source", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAddSource) {
                AddSourceView(appState: appState)
                    .frame(width: 400, height: 350)
            }
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
    
    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) {
                    Text("M3U Playlist").tag(StreamType.m3u)
                    Text("Xtream Codes").tag(StreamType.xtream)
                }
                .pickerStyle(.segmented)
            }
            
            Section("Configuration") {
                if type == .m3u {
                    TextField("M3U URL", text: $m3uUrl)
                } else {
                    TextField("Server URL", text: $xtreamUrl)
                    TextField("Username", text: $xtreamUser)
                    SecureField("Password", text: $xtreamPass)
                }
            }
            
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Spacer()
                Button("Add Source") {
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
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
            .padding(.top)
        }
        .padding()
    }
}
