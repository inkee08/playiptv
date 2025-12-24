import datetime
import os
import sys

# Configuration
M3U_FILENAME = "test-playlist.m3u"
XML_FILENAME = "test-epg.xml"
CHANNEL_ID = "test.channel.1"
CHANNEL_NAME = "Test Channel Auto-Update"
STREAM_URL = "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

def generate_files():
    # 1. Generate XMLTV Date Format: YYYYMMDDhhmmss +0000
    now = datetime.datetime.now(datetime.timezone.utc)
    
    # Define Timings
    # Show 1: Started 30 mins ago, Ends in 2 minutes from NOW
    start1 = now - datetime.timedelta(minutes=30)
    end1 = now + datetime.timedelta(minutes=2)
    
    # Show 2: Starts in 2 minutes, Ends in 60 minutes
    start2 = end1
    end2 = now + datetime.timedelta(minutes=62)
    
    def format_date(dt):
        return dt.strftime("%Y%m%d%H%M%S +0000")

    xml_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tv SYSTEM "xmltv.dtd">
<tv generator-info-name="TestGenerator">
  <channel id="{CHANNEL_ID}">
    <display-name>{CHANNEL_NAME}</display-name>
  </channel>
  
  <programme start="{format_date(start1)}" stop="{format_date(end1)}" channel="{CHANNEL_ID}">
    <title lang="en">Test Show 1 (Ending in 2 min)</title>
    <desc lang="en">This show should change automatically to Show 2 shortly.</desc>
  </programme>
  
  <programme start="{format_date(start2)}" stop="{format_date(end2)}" channel="{CHANNEL_ID}">
    <title lang="en">Test Show 2 (Auto-Updated!)</title>
    <desc lang="en">If you see this, the auto-refresh worked!</desc>
  </programme>
</tv>
"""

    # 2. Generate M3U
    m3u_content = f"""#EXTM3U
#EXTINF:-1 tvg-id="{CHANNEL_ID}" tvg-name="{CHANNEL_NAME}" group-title="Test Group",{CHANNEL_NAME}
{STREAM_URL}
"""

    # Write files
    cwd = os.getcwd()
    with open(M3U_FILENAME, "w") as f:
        f.write(m3u_content)
        
    with open(XML_FILENAME, "w") as f:
        f.write(xml_content)
        
    print(f"✅ Generated {M3U_FILENAME}")
    print(f"✅ Generated {XML_FILENAME}")
    print("\n" + "="*50)
    print("COPY THIS INTO YOUR debug-config.json 'sources' array:")
    print("="*50)
    
    json_snippet = f"""    {{
      "name": "Auto-Update Test Source",
      "type": "m3u",
      "m3uUrl": "file://{cwd}/{M3U_FILENAME}",
      "epgUrl": "file://{cwd}/{XML_FILENAME}"
    }}"""
    
    print(json_snippet)
    print("="*50)

if __name__ == "__main__":
    generate_files()
