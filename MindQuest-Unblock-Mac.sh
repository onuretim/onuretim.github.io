#!/usr/bin/env bash
# MindQuest Instant Unblock Script for macOS / Linux
# Removes all blocked domain entries and flushes the OS DNS cache immediately

echo "🔓 Unlocking all blocked websites on this machine..."

# Remove tagged MindQuest blocks
sudo sed -i '' '/# --- MindQuest/,/# --- End MindQuest/d' /etc/hosts 2>/dev/null || true

# Remove individual distraction domain lines (YouTube, TikTok, Social, etc.)
sudo sed -i '' '/youtube\.com/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/youtu\.be/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/tiktok/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/instagram/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/reddit/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/pornhub/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/xvideos/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/stake\.com/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/roobet/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/shein/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/temu/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/dailymail/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/9gag/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/steampowered/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/roblox/d' /etc/hosts 2>/dev/null || true

# Flush OS DNS Caches
if [[ "$OSTYPE" == "darwin"* ]]; then
    sudo dscacheutil -flushcache 2>/dev/null || true
    sudo killall -HUP mDNSResponder 2>/dev/null || true
fi

echo ""
echo "=========================================================="
echo "🎉 SUCCESS: All websites are now completely UNLOCKED!"
echo "   DNS cache flushed. You can now access YouTube and all apps."
echo "=========================================================="
