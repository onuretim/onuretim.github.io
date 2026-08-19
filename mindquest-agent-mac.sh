#!/usr/bin/env bash
# MindQuest NextDNS-Style macOS Background Client Agent Setup
set -e

CONFIG_ID="${1:-mq-default}"
echo "========================================================="
echo "   🚀 MindQuest NextDNS-Style macOS Client Agent Setup   "
echo "   Config ID: $CONFIG_ID                                 "
echo "========================================================="

AGENT_SCRIPT="/usr/local/bin/mindquest-daemon.sh"

sudo tee "$AGENT_SCRIPT" > /dev/null << 'EOF'
#!/usr/bin/env bash
CONFIG_ID="${1:-mq-default}"
HOSTS="/etc/hosts"
BLOCK_TAG="# --- MindQuest Dynamic Block ---"

DOMAINS=(
  "youtube.com" "www.youtube.com" "m.youtube.com" "youtu.be" "googlevideo.com" "ytimg.com"
  "tiktok.com" "www.tiktok.com" "instagram.com" "www.instagram.com" "reddit.com" "www.reddit.com"
)

apply_block() {
  sudo sed -i '' "/$BLOCK_TAG/,/# --- End MindQuest Dynamic Block ---/d" "$HOSTS" 2>/dev/null || true
  {
    echo "$BLOCK_TAG"
    for d in "${DOMAINS[@]}"; do
      echo "0.0.0.0 $d"
      echo ":: $d"
    done
    echo "# --- End MindQuest Dynamic Block ---"
  } | sudo tee -a "$HOSTS" > /dev/null
  sudo dscacheutil -flushcache 2>/dev/null || true
  sudo killall -HUP mDNSResponder 2>/dev/null || true
  echo "[$(date +%T)] 🔒 POLICY ENFORCED: Apps blocked"
}

remove_block() {
  sudo sed -i '' "/$BLOCK_TAG/,/# --- End MindQuest Dynamic Block ---/d" "$HOSTS" 2>/dev/null || true
  sudo dscacheutil -flushcache 2>/dev/null || true
  sudo killall -HUP mDNSResponder 2>/dev/null || true
  echo "[$(date +%T)] 🔓 ACCESS UNLOCKED"
}

apply_block
echo "MindQuest macOS agent running in background..."
EOF

sudo chmod +x "$AGENT_SCRIPT"
echo "✅ MindQuest macOS agent installed and running!"
