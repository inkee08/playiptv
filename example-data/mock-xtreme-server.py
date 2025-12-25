#!/usr/bin/env python3
"""
Simple mock Xtreme Codes API server for testing PlayIPTV
Run this script and use http://localhost:8000 as your Xtreme source URL
Username: test
Password: test
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import urllib.parse

class XtremeAPIHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Parse the URL
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        
        # Special case: EPG XML file (no auth required for EPG)
        if parsed.path == '/xmltv.php' or 'xmltv' in parsed.path.lower():
            self.serve_epg()
            return
        
        # Special case: M3U playlist file (no auth required)
        if parsed.path == '/playlist.m3u' or parsed.path.endswith('.m3u'):
            self.serve_m3u()
            return
        
        # Check authentication (username=test, password=test)
        if query.get('username') != ['test'] or query.get('password') != ['test']:
            self.send_error(401, 'Unauthorized')
            return
        
        action = query.get('action', [''])[0]
        
        # Route to appropriate endpoint
        if action == 'get_live_categories':
            self.serve_file('example-xtreme-categories.json')
        elif action == 'get_vod_categories':
            self.serve_file('example-xtreme-categories.json')
        elif action == 'get_series_categories':
            self.serve_file('example-xtreme-categories.json')
        elif action == 'get_live_streams':
            self.serve_file('example-xtreme-live.json')
        elif action == 'get_vod_streams':
            self.serve_file('example-xtreme-vod.json')
        elif action == 'get_series':
            self.serve_file('example-xtreme-series.json')
        elif action == 'get_series_info':
            series_id = query.get('series_id', [''])[0]
            if series_id == '3001':
                self.serve_file('example-xtreme-episodes-3001.json')
            elif series_id == '3002':
                self.serve_file('example-xtreme-episodes-3002.json')
            else:
                self.send_error(404, 'Series not found')
        else:
            self.send_error(404, 'Unknown action')
    
    def serve_epg(self):
        """Serve EPG XML file"""
        try:
            with open('example-epg.xml', 'r') as f:
                content = f.read()
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/xml')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(content.encode())
            print("  → Served EPG XML")
        except FileNotFoundError:
            self.send_error(404, 'EPG file not found')
    
    def serve_m3u(self):
        """Serve M3U playlist file"""
        try:
            with open('example-playlist.m3u', 'r') as f:
                content = f.read()
            
            self.send_response(200)
            self.send_header('Content-Type', 'audio/x-mpegurl')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(content.encode())
            print("  → Served M3U playlist")
        except FileNotFoundError:
            self.send_error(404, 'M3U file not found')
    
    def serve_file(self, filename):
        try:
            with open(filename, 'r') as f:
                content = f.read()
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(content.encode())
        except FileNotFoundError:
            self.send_error(404, f'File {filename} not found')
    
    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {format % args}")

def run_server(port=8000):
    server_address = ('', port)
    httpd = HTTPServer(server_address, XtremeAPIHandler)
    print(f"""
╔════════════════════════════════════════════════════════════╗
║         Mock Xtreme Codes API Server Running              ║
╠════════════════════════════════════════════════════════════╣
║  Xtreme API URL:  http://localhost:{port}                   ║
║  Username:        test                                     ║
║  Password:        test                                     ║
║                                                            ║
║  M3U Playlist:    http://localhost:{port}/playlist.m3u       ║
║  EPG URL:         http://localhost:{port}/xmltv.php          ║
╠════════════════════════════════════════════════════════════╣
║  For Xtreme Codes API source:                             ║
║  1. Open Settings → Sources → Add Source                   ║
║  2. Select "Xtreme Codes API"                              ║
║  3. Enter URL, username, password above                    ║
║  4. (Optional) Add EPG URL                                 ║
║                                                            ║
║  For M3U Playlist source:                                  ║
║  1. Open Settings → Sources → Add Source                   ║
║  2. Select "M3U Playlist"                                  ║
║  3. Enter M3U URL above                                    ║
║  4. EPG is auto-configured in the M3U file                 ║
╚════════════════════════════════════════════════════════════╝
    """)
    httpd.serve_forever()

if __name__ == '__main__':
    run_server()
