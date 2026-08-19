#!/usr/bin/env bash
# MindQuest Anti-Gravity YouTube Block for macOS / Linux
set -e

BLOCK_TAG="# --- MindQuest DNS Block ---"
DOMAINS=(
  "youtube.com"
  "www.youtube.com"
  "m.youtube.com"
  "youtu.be"
  "youtube-nocookie.com"
  "googlevideo.com"
  "ytimg.com"
  "yt3.ggpht.com"
  "youtubei.googleapis.com"
)

sudo sed -i '' "/$BLOCK_TAG/,/# --- End MindQuest DNS Block ---/d" /etc/hosts 2>/dev/null || true

{
  echo "$BLOCK_TAG"
  for d in "${DOMAINS[@]}"; do
    echo "0.0.0.0 $d"
    echo ":: $d"
  done
  echo "# --- End MindQuest DNS Block ---"
} | sudo tee -a /etc/hosts > /dev/null

sudo dscacheutil -flushcache 2>/dev/null || true
sudo killall -HUP mDNSResponder 2>/dev/null || true

echo "✅ YouTube is now 100% BLOCKED on macOS!"
