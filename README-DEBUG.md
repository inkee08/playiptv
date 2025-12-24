# Debug Configuration

For faster development/testing, you can create a `debug-config.json` file in the project root with your source credentials. This file is gitignored and will auto-load all sources on app startup.

## Setup

1. Copy the example file:
```bash
cp debug-config.json.example debug-config.json
```

2. Edit `debug-config.json` with your sources:
```json
{
  "sources": [
    {
      "name": "My Xtream Source",
      "type": "xtream",
      "xtreamUrl": "https://your-server.com",
      "username": "your_username",
      "password": "your_password"
    },
    {
      "name": "My M3U Playlist",
      "type": "m3u",
      "m3uUrl": "https://example.com/playlist.m3u"
    }
  ]
}
```

You can have multiple sources of either type. Just add/remove objects from the `sources` array.

3. Run the app - all your sources will be automatically loaded!

**Note:** This file is gitignored and will never be committed to the repository.
