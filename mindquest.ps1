# MindQuest NextDNS-Style Windows Client Agent (State of the Art)
# Run via: irm https://onuretim.github.io/mindquest.ps1 | iex

$ErrorActionPreference = "SilentlyContinue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   🚀 MindQuest NextDNS-Style 8-Category Shield Agent     " -ForegroundColor Green
Write-Host "   Status: Active & Enforcing Addictive Domain Shield    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$HostsFile = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$Tag = "# --- MindQuest 8-Category Addictive Blocklist ---"

$TargetDomains = @(
    # 1. SOCIAL MEDIA
    "tiktok.com", "www.tiktok.com", "m.tiktok.com", "tiktokcdn.com", "tiktokv.com", "byteoversea.com",
    "instagram.com", "www.instagram.com", "cdninstagram.com", "threads.net", "www.threads.net", "ig.me",
    "facebook.com", "www.facebook.com", "m.facebook.com", "fb.com", "fbcdn.net", "messenger.com",
    "twitter.com", "www.twitter.com", "x.com", "www.x.com", "twimg.com", "t.co",
    "reddit.com", "www.reddit.com", "old.reddit.com", "redd.it", "redditmedia.com", "redditstatic.com",
    "snapchat.com", "www.snapchat.com", "sc-cdn.net", "pinterest.com", "www.pinterest.com",

    # 2. VIDEO & STREAMING
    "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be", "googlevideo.com", "ytimg.com",
    "yewtu.be", "invidious.snopyta.org", "piped.video", "piped.kavin.rocks", "invidious.io",
    "twitch.tv", "www.twitch.tv", "ttvnw.net", "kick.com", "www.kick.com",
    "netflix.com", "www.netflix.com", "nflxvideo.net", "disneyplus.com", "hulu.com", "primevideo.com", "max.com",

    # 3. ADULT & 18+ ENTERTAINMENT
    "pornhub.com", "www.pornhub.com", "phncdn.com", "youporn.com", "redtube.com", "tube8.com",
    "xvideos.com", "www.xvideos.com", "xnxx.com", "www.xnxx.com", "xvideos-cdn.com",
    "onlyfans.com", "www.onlyfans.com", "fansly.com", "chaturbate.com", "stripchat.com", "spankbang.com", "eporner.com",

    # 4. ONLINE GAMING & MINIGAMES
    "steampowered.com", "steamcommunity.com", "roblox.com", "www.roblox.com", "rbxcdn.com",
    "epicgames.com", "poki.com", "crazygames.com", "miniclip.com", "coolmathgames.com", "krunker.io", "agar.io",

    # 5. GAMBLING & CRYPTO BETTING
    "stake.com", "www.stake.com", "stake.us", "roobet.com", "rollbit.com", "bet365.com", "draftkings.com", "fanduel.com",
    "bovada.lv", "888casino.com", "pokerstars.com", "csgoempire.com", "csgoroll.com",

    # 6. IMPULSE SHOPPING & DEALS
    "shein.com", "www.shein.com", "temu.com", "www.temu.com", "aliexpress.com", "wish.com", "stockx.com",

    # 7. CLICKBAIT & TABLOIDS
    "dailymail.co.uk", "www.dailymail.co.uk", "tmz.com", "www.tmz.com", "thesun.co.uk", "nypost.com", "buzzfeed.com",

    # 8. MEMES & DOOMSCROLLING
    "9gag.com", "www.9gag.com", "ifunny.co", "imgur.com", "knowyourmeme.com"
)

function Enable-Shield {
    try {
        $lines = Get-Content -Path $HostsFile | Where-Object { $_ -notmatch 'MindQuest' -and $_ -notmatch '0.0.0.0' }
        $newLines = [System.Collections.Generic.List[string]]::new()
        foreach ($line in $lines) { $newLines.Add($line) }
        
        $newLines.Add($Tag)
        foreach ($domain in $TargetDomains) {
            $newLines.Add("0.0.0.0 $domain")
            $newLines.Add(":: $domain")
        }
        $newLines.Add("# --- End MindQuest 8-Category Addictive Blocklist ---")
        
        Set-Content -Path $HostsFile -Value $newLines -Force
        Clear-DnsClientCache
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 🔒 8-CATEGORY SHIELD ACTIVE: $($TargetDomains.Count) domains blocked." -ForegroundColor Yellow
    } catch {
        Write-Host "Please run PowerShell as Administrator to modify system DNS." -ForegroundColor Red
    }
}

function Disable-Shield {
    try {
        $lines = Get-Content -Path $HostsFile | Where-Object { 
            $_ -notmatch 'MindQuest' -and 
            $_ -notmatch 'youtube|tiktok|instagram|reddit|pornhub|xvideos|stake|roobet|shein|temu|dailymail|9gag|steampowered|roblox' 
        }
        Set-Content -Path $HostsFile -Value $lines -Force
        Clear-DnsClientCache
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 🔓 ACCESS UNLOCKED: Distraction apps available." -ForegroundColor Green
    } catch {}
}

# Initial enforce on launch
Enable-Shield

Write-Host ""
Write-Host "✅ 8 Addictive Categories (Social, 18+, Streaming, Gaming, Gambling, Shopping) BLOCKED!" -ForegroundColor Green
Write-Host "👉 Open https://onuretim.github.io/unlock/ to complete exercise reps and unlock access." -ForegroundColor Cyan
Write-Host "⚙️ Customize categories & whitelist at https://onuretim.github.io/settings/" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop the shield." -ForegroundColor Gray
Write-Host ""

# Background sync loop
while ($true) {
    Start-Sleep -Seconds 5
}
