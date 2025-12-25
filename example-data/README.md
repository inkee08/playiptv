# Example Data for PlayIPTV Testing

This directory contains example Xtreme Codes API data and a mock server for testing PlayIPTV.

## Files

- **`mock-xtreme-server.py`** - Python HTTP server that simulates an Xtreme Codes API and serves M3U playlists
- **`example-playlist.m3u`** - M3U playlist with live channels and movies
- **`example-xtreme-categories.json`** - Category definitions
- **`example-xtreme-live.json`** - Live TV channels (BBC One HD, CNN, ESPN)
- **`example-xtreme-vod.json`** - Movies (The Matrix, Inception, Shawshank Redemption)
- **`example-xtreme-series.json`** - TV series (Breaking Bad, Stranger Things)
- **`example-xtreme-episodes-3001.json`** - Breaking Bad episodes
- **`example-xtreme-episodes-3002.json`** - Stranger Things episodes
- **`example-epg.xml`** - EPG/TV guide data for the live channels

## Usage

1. **Start the mock server:**
   ```bash
   cd example-data
   python3 mock-xtreme-server.py
   ```

2. **Add source in PlayIPTV:**
   
   **Option A: Xtreme Codes API**
   - Open Settings → Sources
   - Click "Add Source"
   - Select "Xtreme Codes API"
   - Enter:
     - **URL:** `http://localhost:8000`
     - **Username:** `test`
     - **Password:** `test`
   - (Optional) Add EPG URL: `http://localhost:8000/xmltv.php`
   
   **Option B: M3U Playlist**
   - Open Settings → Sources
   - Click "Add Source"
   - Select "M3U Playlist"
   - Enter URL: `http://localhost:8000/playlist.m3u`
   - EPG is automatically configured in the M3U file

3. **Test the app:**
   - Browse live TV channels with EPG data
   - Watch movies
   - Browse series and play episodes
   - Test favorites, recent VOD, playback controls, etc.

## What's Included

### Live TV (3 channels)
- BBC One HD - UK entertainment with 7-day archive
- CNN International - News channel
- ESPN HD - Sports channel with 3-day archive

### Movies (3 titles)
- The Matrix (Action)
- Inception (Action)
- The Shawshank Redemption (Drama)

### Series (2 shows with episodes)
- Breaking Bad - 2 seasons, 3 episodes
- Stranger Things - 1 season, 2 episodes

### EPG Data
- Full day's programming for all live channels
- Realistic show titles, descriptions, and categories
