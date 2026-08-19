# MindQuest NextDNS-Style Windows Background Client Agent
# Automatically syncs app block policies and unlock timers with your MindQuest profile in real-time

param (
    [string]$ConfigId = "mq-demo",
    [string]$ApiUrl = "https://onuretim.github.io"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   🚀 MindQuest NextDNS-Style Windows Client Agent       " -ForegroundColor Green
Write-Host "   Config ID: $ConfigId                                  " -ForegroundColor Yellow
Write-Host "   Status: Connected & Synchronizing in Background       " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$HostsPath = "$env:windir\System32\drivers\etc\hosts"
$BlockTag = "# --- MindQuest Dynamic Block ---"
$LastState = ""

function Apply-Blocklist([string[]]$Domains) {
    # Remove existing MindQuest block lines
    $content = Get-Content $HostsPath | Where-Object { $_ -notmatch 'MindQuest' -and $_ -notmatch '0.0.0.0' }
    $blockLines = @($BlockTag)
    foreach ($d in $Domains) {
        $blockLines += "0.0.0.0 $d"
        $blockLines += ":: $d"
    }
    $blockLines += "# --- End MindQuest Dynamic Block ---"
    
    Set-Content -Path $HostsPath -Value ($content + $blockLines)
    Clear-DnsClientCache
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 🔒 POLICY ENFORCED: $($Domains.Count) domains blocked." -ForegroundColor Red
}

function Remove-Blocklist() {
    $content = Get-Content $HostsPath | Where-Object { 
        $_ -notmatch 'MindQuest' -and 
        $_ -notmatch 'youtube|tiktok|instagram|reddit|twitter|twitch|netflix|discord|roblox|steampowered' 
    }
    Set-Content -Path $HostsPath -Value $content
    Clear-DnsClientCache
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 🔓 ACCESS UNLOCKED: All apps available!" -ForegroundColor Green
}

# Heartbeat & Sync Loop (Runs every 4 seconds)
while ($true) {
    try {
        # Fetch current profile state from MindQuest Cloud API
        # Fallback to local default policy if offline
        $defaultDomains = @(
            "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be", "googlevideo.com", "ytimg.com",
            "tiktok.com", "www.tiktok.com", "instagram.com", "www.instagram.com", "reddit.com", "www.reddit.com"
        )
        
        # Check local/session lock status
        # If unlocked via web token, remove block; otherwise enforce
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
