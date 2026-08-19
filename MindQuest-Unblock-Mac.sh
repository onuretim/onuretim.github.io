#!/usr/bin/env bash
# MindQuest Anti-Gravity YouTube Unblock for macOS / Linux
set -e

BLOCK_TAG="# --- MindQuest DNS Block ---"
sudo sed -i '' "/$BLOCK_TAG/,/# --- End MindQuest DNS Block ---/d" /etc/hosts 2>/dev/null || true
sudo dscacheutil -flushcache 2>/dev/null || true
sudo killall -HUP mDNSResponder 2>/dev/null || true

echo "✅ YouTube access is UNLOCKED!"
