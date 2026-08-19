# MindQuest NextDNS-Style Windows Client Agent (State of the Art)
# Run via: irm https://onuretim.github.io/mindquest.ps1 | iex

$ErrorActionPreference = "SilentlyContinue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   🚀 MindQuest NextDNS-Style Windows Client Agent       " -ForegroundColor Green
Write-Host "   Status: Active & Enforcing Distraction Shield         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$HostsFile = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$Tag = "# --- MindQuest Dynamic Block ---"

$TargetDomains = @(
    "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be", "googlevideo.com", "ytimg.com", "yt3.ggpht.com",
    "tiktok.com", "www.tiktok.com", "m.tiktok.com", "tiktokcdn.com",
    "instagram.com", "www.instagram.com", "cdninstagram.com",
    "reddit.com", "www.reddit.com", "redd.it", "redditmedia.com"
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
        $newLines.Add("# --- End MindQuest Dynamic Block ---")
        
        Set-Content -Path $HostsFile -Value $newLines -Force
        Clear-DnsClientCache
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 🔒 SHIELD ACTIVE: $($TargetDomains.Count) domains blocked." -ForegroundColor Yellow
    } catch {
        Write-Host "Please run PowerShell as Administrator to modify system DNS." -ForegroundColor Red
    }
}

function Disable-Shield {
    try {
        $lines = Get-Content -Path $HostsFile | Where-Object { 
            $_ -notmatch 'MindQuest' -and 
            $_ -notmatch 'youtube|tiktok|instagram|reddit|googlevideo|ytimg|cdninstagram' 
        }
        Set-Content -Path $HostsFile -Value $lines -Force
        Clear-DnsClientCache
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 🔓 ACCESS UNLOCKED: Distraction apps available." -ForegroundColor Green
    } catch {}
}

# Initial enforce on launch
Enable-Shield

Write-Host ""
Write-Host "✅ YouTube, TikTok, Instagram & Reddit are now BLOCKED on this PC!" -ForegroundColor Green
Write-Host "👉 Open https://onuretim.github.io/unlock/ to complete exercise reps and unlock access." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop the shield." -ForegroundColor Gray
Write-Host ""

# Background sync loop
while ($true) {
    Start-Sleep -Seconds 5
}
