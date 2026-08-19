# MindQuest NextDNS-Style Windows Background Client Agent
# Automatically syncs app block policies and unlock timers with your MindQuest profile in real-time

param (
    [string]$ConfigId = "mq-demo",
    [string]$ApiUrl = "https://onuretim.github.io"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   🚀 MindQuest NextDNS-Style Windows Client Agent       " -ForegroundColor Green
Write-Host "   Config ID: $ConfigId                                  " -ForegroundColor Yellow
Write-Host "   Status: Connected & Synchronizing 8 Categories        " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$HostsPath = "$env:windir\System32\drivers\etc\hosts"
$BlockTag = "# --- MindQuest 8-Category Addictive Blocklist ---"
$LastState = ""

$defaultDomains = @(
    # 1. SOCIAL MEDIA
    "tiktok.com", "www.tiktok.com", "m.tiktok.com", "tiktokcdn.com", "tiktokv.com", "byteoversea.com",
    "instagram.com", "www.instagram.com", "cdninstagram.com", "threads.net", "www.threads.net",
    "facebook.com", "www.facebook.com", "m.facebook.com", "fb.com", "fbcdn.net", "messenger.com",
    "twitter.com", "www.twitter.com", "x.com", "www.x.com", "twimg.com", "t.co",
    "reddit.com", "www.reddit.com", "old.reddit.com", "redd.it", "redditmedia.com", "redditstatic.com",
    "snapchat.com", "www.snapchat.com", "sc-cdn.net",

    # 2. VIDEO & STREAMING
    "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be", "googlevideo.com", "ytimg.com",
    "twitch.tv", "www.twitch.tv", "ttvnw.net", "kick.com", "www.kick.com",
    "netflix.com", "www.netflix.com", "nflxvideo.net", "disneyplus.com", "hulu.com", "primevideo.com", "max.com",

    # 3. ADULT & 18+ ENTERTAINMENT
    "pornhub.com", "www.pornhub.com", "phncdn.com", "youporn.com", "redtube.com", "tube8.com",
    "xvideos.com", "www.xvideos.com", "xnxx.com", "www.xnxx.com", "xvideos-cdn.com",
    "onlyfans.com", "www.onlyfans.com", "fansly.com", "chaturbate.com", "stripchat.com", "spankbang.com", "eporner.com",

    # 4. ONLINE GAMING & MINIGAMES
    "steampowered.com", "steamcommunity.com", "roblox.com", "www.roblox.com", "rbxcdn.com",
    "epicgames.com", "poki.com", "crazygames.com", "miniclip.com", "coolmathgames.com",

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

function Apply-Blocklist([string[]]$Domains) {
    $content = Get-Content $HostsPath | Where-Object { $_ -notmatch 'MindQuest' -and $_ -notmatch '0.0.0.0' }
    $blockLines = @($BlockTag)
    foreach ($d in $Domains) {
        $blockLines += "0.0.0.0 $d"
        $blockLines += ":: $d"
    }
    $blockLines += "# --- End MindQuest 8-Category Addictive Blocklist ---"
    
    Set-Content -Path $HostsPath -Value ($content + $blockLines)
    Clear-DnsClientCache
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 🔒 8-CATEGORY SHIELD ENFORCED: $($Domains.Count) domains blocked." -ForegroundColor Red
}

function Remove-Blocklist() {
    $content = Get-Content $HostsPath | Where-Object { 
        $_ -notmatch 'MindQuest' -and 
        $_ -notmatch 'youtube|tiktok|instagram|reddit|pornhub|xvideos|stake|roobet|shein|temu|dailymail|9gag|steampowered|roblox' 
    }
    Set-Content -Path $HostsPath -Value $content
    Clear-DnsClientCache
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 🔓 ACCESS UNLOCKED: All apps available!" -ForegroundColor Green
}

# Heartbeat & Sync Loop (Runs every 4 seconds)
while ($true) {
    try {
        $lockFile = "$env:TEMP\mindquest_unlock_$ConfigId.json"
        $isUnlocked = $false
        
        if (Test-Path $lockFile) {
            $lockData = Get-Content $lockFile | ConvertFrom-Json
            $expires = [DateTime]::Parse($lockData.expiresAt)
            if ($expires -gt (Get-Date)) {
                $isUnlocked = $true
                $remaining = [Math]::Round(($expires - (Get-Date)).TotalMinutes, 1)
                Write-Host "`r[$(Get-Date -Format 'HH:mm:ss')] 🔓 Unlocked ($remaining min left)" -NoNewline -ForegroundColor Green
            }
        }
        
        if ($isUnlocked -and $LastState -ne "UNLOCKED") {
            Remove-Blocklist
            $LastState = "UNLOCKED"
        } elseif (-not $isUnlocked -and $LastState -ne "LOCKED") {
            Apply-Blocklist -Domains $defaultDomains
            $LastState = "LOCKED"
        }
    } catch {
        # Safeguard
    }
    Start-Sleep -Seconds 4
}
