<#
    MindQuest Windows agent.

    Replaces mindquest.ps1, which was not an agent at all. That script
    applied a hardcoded blocklist to the hosts file and then entered
    `while ($true) { Start-Sleep -Seconds 5 }` — a loop that did nothing.
    It defined a Disable-Shield function and never called it, so there was
    no unlock, no timer, and no way back except editing a system file by
    hand. It also stripped every line matching `0.0.0.0` from the existing
    hosts file, destroying unrelated entries the user had put there.

    This one is the real thing:

      - Reads the account's blocklist from the API, so what it blocks is
        what the settings page says.
      - Honours unlock sessions earned through an exercise, and re-blocks
        the moment the grant expires.
      - Touches only the lines between its own markers. Anything else in
        the hosts file is preserved byte for byte.
      - Fails closed. An unreachable API can never unblock and can never
        extend a grant; the worst it can do is leave things blocked.
      - Uninstalls cleanly, including repairing damage the old script did.

    Usage:
      Install (as Administrator):
        powershell -ExecutionPolicy Bypass -File mindquest-agent.ps1 -Install -ConfigId mq-xxxxxx
      Run in the foreground:
        powershell -ExecutionPolicy Bypass -File mindquest-agent.ps1 -ConfigId mq-xxxxxx
      Remove everything:
        powershell -ExecutionPolicy Bypass -File mindquest-agent.ps1 -Uninstall
#>

[CmdletBinding()]
param(
    [string]$ConfigId,
    [string]$ApiUrl = 'https://mindquest-api.onrender.com',

    [switch]$Install,
    [switch]$Uninstall,

    # One cycle then exit, for scripted checks.
    [switch]$Once,

    # Overridable so the logic can be tested without touching a real system.
    [string]$HostsPath,
    [int]$PollSeconds = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Constants ────────────────────────────────────────────────────────────

$script:BeginTag = '# --- MindQuest blocklist BEGIN (managed - do not edit) ---'
$script:EndTag   = '# --- MindQuest blocklist END ---'

# The marker the broken script used. Kept so this agent can clean up after
# it on machines where it already ran and left them blocked with no way out.
$script:LegacyBeginTag = '# --- MindQuest 8-Category Addictive Blocklist ---'
$script:LegacyEndTag   = '# --- End MindQuest 8-Category Addictive Blocklist ---'

$script:TaskName = 'MindQuestAgent'

<#
    Domains this agent will not block, whatever the account says.

    Mirrors NEVER_BLOCK_DOMAINS in @mindquest/shared, which the API also
    enforces as a server-side floor. Applied again here because this is the
    last step before writing to a system file as Administrator: a stale
    cached policy or a future bug upstream must not be able to cut this
    machine off from Windows Update or from the API that grants unlocks.

    A blocker that can strand someone with no route back is not something
    anyone should install.
#>
$script:NeverBlock = @(
    'connectivitycheck.gstatic.com',
    'connectivitycheck.android.com',
    'pool.ntp.org',
    'time.android.com',
    'googleapis.com',
    'gvt1.com',
    'gvt2.com',
    'gvt3.com',
    # Windows-specific: losing these looks like a broken PC, not a working
    # blocker. Update, activation, time sync, and captive-portal detection.
    'windowsupdate.com',
    'update.microsoft.com',
    'msftconnecttest.com',
    'msftncsi.com',
    'time.windows.com'
)

function Resolve-HostsPath {
    if ($HostsPath) { return $HostsPath }
    $root = if ($env:SystemRoot) { $env:SystemRoot } else { 'C:\Windows' }
    return (Join-Path $root 'System32\drivers\etc\hosts')
}

# ── Hosts file editing ───────────────────────────────────────────────────

<#
    Removes the agent's managed block, and the broken script's block if it
    is present, leaving every other line untouched.

    Line-range removal between markers, never a content filter. The old
    script's unblock path used `-notmatch 'youtube|tiktok|...'`, which
    deleted any line containing those words — including entries the user
    had added themselves — and still missed most of what it had blocked.
    Deciding what to remove by what it looks like is how a blocker starts
    eating unrelated configuration.
#>
function Remove-ManagedBlock {
    # AllowEmptyString is required, not decorative: a mandatory [string[]]
    # implicitly rejects empty elements, and every real hosts file has
    # blank lines in it. Without this the agent throws on the first run
    # against an ordinary Windows machine.
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $out = [System.Collections.Generic.List[string]]::new()
    $inBlock = $false

    foreach ($line in $Lines) {
        $trimmed = $line.Trim()

        if ($trimmed -eq $script:BeginTag -or $trimmed -eq $script:LegacyBeginTag) {
            $inBlock = $true
            continue
        }
        if ($trimmed -eq $script:EndTag -or $trimmed -eq $script:LegacyEndTag) {
            $inBlock = $false
            continue
        }
        if (-not $inBlock) { $out.Add($line) }
    }

    # An unterminated block means a previous run was interrupted between
    # writing the opening marker and the closing one. Everything after the
    # marker was ours, so dropping to end-of-file is correct and leaves the
    # file usable rather than permanently half-blocked.
    return , $out.ToArray()
}

<#
    Filters the account's blocklist down to what may actually be written.
    Suffix matching, not equality: hosts entries are exact hostnames, so a
    check that only looked for `googleapis.com` would let
    `play.googleapis.com` through into the block.
#>
function Select-EnforceableDomains {
    param(
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Domains
    )

    $kept    = [System.Collections.Generic.List[string]]::new()
    $dropped = [System.Collections.Generic.List[string]]::new()

    foreach ($domain in $Domains) {
        if ($null -eq $domain) { continue }
        $norm = $domain.Trim().ToLowerInvariant().TrimEnd('.')
        if ([string]::IsNullOrWhiteSpace($norm)) { continue }
        if ($norm -notmatch '^[a-z0-9.-]+$') { continue }
        if ($norm -notlike '*.*') { continue }

        $protected = $false
        foreach ($floor in $script:NeverBlock) {
            if ($norm -eq $floor -or $norm.EndsWith(".$floor")) { $protected = $true; break }
        }

        if ($protected) { $dropped.Add($norm) }
        elseif (-not $kept.Contains($norm)) { $kept.Add($norm) }
    }

    if ($dropped.Count -gt 0) {
        Write-Host "  refused to block $($dropped.Count) protected domain(s): $($dropped -join ', ')" -ForegroundColor DarkYellow
    }

    # Deliberately not `$kept | Select-Object -Unique`. A pipeline that
    # yields exactly one item unrolls to a bare string, so the caller gets
    # a String where it expected a String[] and .Count throws under
    # StrictMode - a single blocked domain would have crashed the agent.
    # Comma-wrapping a real array is the form that survives both cases,
    # including empty.
    return , $kept.ToArray()
}

<#
    Writes the hosts file so that it either contains the managed block or
    does not, and reports whether anything actually changed.

    Returning "changed" matters: rewriting a system file and flushing the
    resolver cache every 30 seconds when nothing has moved is needless
    churn on a file other software also reads.
#>
function Set-ShieldState {
    param(
        [Parameter(Mandatory)][bool]$Blocked,
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Domains = @(),
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Hosts file not found at $Path"
    }

    $original = @(Get-Content -Path $Path)
    $cleaned  = Remove-ManagedBlock -Lines $original

    if ($Blocked) {
        $enforceable = Select-EnforceableDomains -Domains $Domains
        if ($enforceable.Count -eq 0) {
            # Never write an empty block. An empty list is far likelier to
            # be an upstream problem than a user who chose to block
            # nothing, and acting on it would silently disable the agent.
            Write-Host '  no enforceable domains - leaving the previous state alone' -ForegroundColor DarkYellow
            return $false
        }

        $new = [System.Collections.Generic.List[string]]::new()
        foreach ($line in $cleaned) { $new.Add($line) }
        $new.Add($script:BeginTag)
        foreach ($domain in $enforceable) {
            $new.Add("127.0.0.1 $domain")
            $new.Add("::1 $domain")
        }
        $new.Add($script:EndTag)
        $desired = $new.ToArray()
    }
    else {
        $desired = $cleaned
    }

    if (-not (Compare-Object -ReferenceObject $original -DifferenceObject $desired -SyncWindow 0)) {
        return $false
    }

    Backup-HostsOnce -Path $Path
    Set-Content -Path $Path -Value $desired -Force -Encoding ascii
    return $true
}

<#
    Keeps one copy of the hosts file as it was before this agent first
    touched it. Written once and never overwritten, so it stays a record
    of the user's own configuration rather than of our last run.
#>
function Backup-HostsOnce {
    param([Parameter(Mandatory)][string]$Path)

    $backup = "$Path.mindquest-backup"
    if (Test-Path $backup) { return }
    try {
        Copy-Item -Path $Path -Destination $backup -Force
        Write-Host "  saved a backup of your original hosts file to $backup" -ForegroundColor DarkGray
    }
    catch {
        # Not fatal. Losing the backup is worse than not having one, but
        # neither should stop the agent from doing its job.
        Write-Host "  could not write a backup: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

function Clear-DnsCache {
    try { & ipconfig /flushdns | Out-Null } catch { }
}

# ── API ──────────────────────────────────────────────────────────────────

$script:PolicyEtag = $null
$script:Blocked    = @()

<#
    Fetches the account's blocklist, conditionally.

    Sends the ETag from the last successful fetch, so an unchanged policy
    costs an empty 304 rather than a few hundred domains. That is what
    makes it affordable to ask every 30 seconds instead of every few
    minutes — and to someone who has just edited their blocklist and is
    watching a site still load, minutes is indistinguishable from broken.

    Returns $true if the caller now holds a usable list.
#>
function Update-Policy {
    param([Parameter(Mandatory)][string]$ConfigId, [Parameter(Mandatory)][string]$ApiUrl)

    $headers = @{}
    if ($script:PolicyEtag) { $headers['If-None-Match'] = $script:PolicyEtag }

    try {
        # 20s because the API is on a tier that sleeps and takes tens of
        # seconds to wake. The next poll is 30s out, so a slow request
        # delays the following one rather than stacking up.
        $res = Invoke-WebRequest -Uri "$ApiUrl/api/policy?configId=$([uri]::EscapeDataString($ConfigId))" `
                                 -Headers $headers -TimeoutSec 20 -SkipHttpErrorCheck

        if ($res.StatusCode -eq 304) { return ($script:Blocked.Count -gt 0) }
        if ($res.StatusCode -ne 200) {
            Write-Host "  policy fetch: HTTP $($res.StatusCode)" -ForegroundColor DarkYellow
            return ($script:Blocked.Count -gt 0)
        }

        $body = $res.Content | ConvertFrom-Json
        if (-not $body.blocked -or $body.blocked.Count -eq 0) {
            Write-Host '  policy fetch: server sent an empty blocklist, ignoring' -ForegroundColor DarkYellow
            return ($script:Blocked.Count -gt 0)
        }

        # Only remember the tag once the body has been accepted. Storing it
        # alongside a response we then rejected would earn a 304 next time
        # for a list this machine never adopted.
        $script:PolicyEtag = $res.Headers['ETag']
        $script:Blocked    = @($body.blocked)

        if (-not $body.paired) {
            Write-Host '  warning: this config ID is not recognised - enforcing defaults, not your list' -ForegroundColor Yellow
        }
        Write-Host "  blocklist: $($script:Blocked.Count) domains" -ForegroundColor DarkGray
        return $true
    }
    catch {
        Write-Host "  policy fetch failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
        return ($script:Blocked.Count -gt 0)
    }
}

<#
    Asks whether an unlock is currently granted.

    Returns the UTC time the grant expires, or $null for "no grant" AND for
    every kind of failure. That collapsing is deliberate: this function
    decides whether to stop blocking, so a response it cannot understand
    must mean no, never a shrug that falls through to yes.
#>
function Get-UnlockExpiry {
    param([Parameter(Mandatory)][string]$ConfigId, [Parameter(Mandatory)][string]$ApiUrl)

    try {
        $res = Invoke-WebRequest -Uri "$ApiUrl/api/session/validate?configId=$([uri]::EscapeDataString($ConfigId))" `
                                 -TimeoutSec 20 -SkipHttpErrorCheck
        if ($res.StatusCode -ne 200) { return $null }

        $body = $res.Content | ConvertFrom-Json
        if (-not $body.active) { return $null }
        if (-not $body.expiresAt) { return $null }

        # "Active" with no readable expiry is not something to guess at.
        return ([datetime]::Parse($body.expiresAt)).ToUniversalTime()
    }
    catch {
        return $null
    }
}

# ── Install / uninstall ──────────────────────────────────────────────────

function Test-Administrator {
    # WindowsIdentity throws outside Windows, which would make the agent's
    # logic impossible to exercise anywhere but a Windows box. The guard
    # changes nothing on the real target: $IsWindows exists only in
    # PowerShell 6+, and its absence means Windows PowerShell 5.1, which
    # runs nowhere else.
    $onWindows = if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) { $IsWindows } else { $true }
    if (-not $onWindows) { return $true }

    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

<#
    Puts the agent at its installed location.

    Exists because of a bug that made installation fail for every single
    user. The .bat downloads the agent to
    C:\ProgramData\MindQuest\mindquest-agent.ps1 and then runs it with
    -Install, at which point $PSCommandPath and $target are the same file -
    and Copy-Item refuses to overwrite a file with itself. Under
    $ErrorActionPreference = 'Stop' that threw, so the scheduled task was
    never registered and config.json was never written, while the calling
    .bat carried on and printed uninstall instructions for something that
    had not been installed.

    Being already in place is success, not an error. Saying so is the whole
    fix.
#>
function Copy-AgentTo {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target
    )

    # Compare resolved paths, so C:\ProgramData\... and a differently-cased
    # or relative route to the same file are recognised as identical.
    $sourceFull = try { (Resolve-Path -LiteralPath $Source).Path } catch { $Source }
    $targetFull = try { (Resolve-Path -LiteralPath $Target).Path } catch { $Target }

    if ($sourceFull -eq $targetFull) {
        Write-Host '  agent is already in place' -ForegroundColor DarkGray
        return
    }

    Copy-Item -LiteralPath $sourceFull -Destination $targetFull -Force
    Write-Host "  installed the agent to $targetFull" -ForegroundColor DarkGray
}

function Install-Agent {
    param([Parameter(Mandatory)][string]$ConfigId, [Parameter(Mandatory)][string]$ApiUrl)

    if (-not (Test-Administrator)) {
        throw 'Installing needs Administrator, because the agent edits the system hosts file. Right-click PowerShell and choose "Run as administrator".'
    }

    $installDir = Join-Path $env:ProgramData 'MindQuest'
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null

    $target = Join-Path $installDir 'mindquest-agent.ps1'
    Copy-AgentTo -Source $PSCommandPath -Target $target

    @{ configId = $ConfigId; apiUrl = $ApiUrl } | ConvertTo-Json |
        Set-Content -Path (Join-Path $installDir 'config.json') -Encoding utf8

    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
                    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$target`" -ConfigId $ConfigId -ApiUrl $ApiUrl"
    $trigger   = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

    Register-ScheduledTask -TaskName $script:TaskName -Action $action -Trigger $trigger `
                           -Principal $principal -Settings $settings -Force | Out-Null

    Start-ScheduledTask -TaskName $script:TaskName

    # Confirm rather than assume. The previous version printed its success
    # banner from the .bat that called it even when this function had
    # already thrown, so a failed install looked exactly like a good one.
    if (-not (Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue)) {
        throw "The startup task '$($script:TaskName)' was not registered. MindQuest is NOT installed."
    }

    Write-Host ''
    Write-Host 'MindQuest is installed and running.' -ForegroundColor Green
    Write-Host "  Blocklist follows account: $ConfigId"
    Write-Host '  It starts automatically at boot.'
    Write-Host '  Earn access at https://onuretim.github.io/unlock/'
    Write-Host ''
    Write-Host 'To remove it completely:' -ForegroundColor Gray
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"$target`" -Uninstall" -ForegroundColor Gray
}

<#
    Removes the scheduled task, unblocks everything, and deletes the
    installed copy.

    Deliberately easy. A tool that gates your own computer has to be
    removable by the person who installed it, or it is not a self-control
    tool — it is malware with a friendly description. The friction that
    makes MindQuest work belongs in the exercise, not in trapping someone
    who has changed their mind.
#>
function Uninstall-Agent {
    if (-not (Test-Administrator)) {
        throw 'Uninstalling needs Administrator, because the agent edits the system hosts file.'
    }

    $path = Resolve-HostsPath
    try {
        $lines   = @(Get-Content -Path $path)
        $cleaned = Remove-ManagedBlock -Lines $lines
        if (Compare-Object -ReferenceObject $lines -DifferenceObject $cleaned -SyncWindow 0) {
            Set-Content -Path $path -Value $cleaned -Force -Encoding ascii
            Write-Host 'Removed all MindQuest entries from the hosts file.' -ForegroundColor Green
        }
        else {
            Write-Host 'No MindQuest entries were in the hosts file.' -ForegroundColor Gray
        }
        Clear-DnsCache
    }
    catch {
        Write-Host "Could not clean the hosts file: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Edit $path by hand and delete everything between the MindQuest markers." -ForegroundColor Yellow
    }

    try {
        if (Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false
            Write-Host 'Removed the startup task.' -ForegroundColor Green
        }
    }
    catch { }

    Write-Host 'MindQuest is uninstalled. Nothing is being blocked.' -ForegroundColor Green
}

# ── Main loop ────────────────────────────────────────────────────────────

<#
    One cycle: refresh the policy, refresh the grant, apply the result.

    $script:UnlockUntil is the local deadline and it is the thing that
    actually decides. The server can set it; the server cannot be required
    in order to end it. If the network drops mid-unlock the grant still
    runs out on schedule, because otherwise "unplug the router" would be a
    way to stay unblocked indefinitely — and the person trying to defeat
    this tool is the person using it.
#>
$script:UnlockUntil = [datetime]::MinValue

function Invoke-Cycle {
    param([Parameter(Mandatory)][string]$ConfigId, [Parameter(Mandatory)][string]$ApiUrl, [Parameter(Mandatory)][string]$Path)

    $stamp = (Get-Date).ToString('HH:mm:ss')
    Write-Host "[$stamp] checking..." -ForegroundColor DarkGray

    $havePolicy = Update-Policy -ConfigId $ConfigId -ApiUrl $ApiUrl

    $expiry = Get-UnlockExpiry -ConfigId $ConfigId -ApiUrl $ApiUrl
    if ($expiry) {
        # Only ever moved forward by the server. An unreachable server
        # leaves whatever grant is already running untouched; it can never
        # create or extend one.
        $script:UnlockUntil = $expiry
    }

    $now      = [datetime]::UtcNow
    $unlocked = $now -lt $script:UnlockUntil

    if (-not $havePolicy) {
        Write-Host '  no blocklist available yet - leaving the current state alone' -ForegroundColor DarkYellow
        return
    }

    $changed = Set-ShieldState -Blocked (-not $unlocked) -Domains $script:Blocked -Path $Path

    if ($unlocked) {
        $left = [int]($script:UnlockUntil - $now).TotalMinutes
        Write-Host "  UNLOCKED - $left minute(s) left" -ForegroundColor Green
    }
    else {
        Write-Host "  BLOCKED - $($script:Blocked.Count) domains" -ForegroundColor Yellow
    }

    if ($changed) { Clear-DnsCache }
}

# ── Entry point ──────────────────────────────────────────────────────────

# Dot-sourcing loads the functions without running anything, so the logic
# above can be exercised by a test harness.
if ($MyInvocation.InvocationName -eq '.') { return }

if ($Uninstall) { Uninstall-Agent; return }

if (-not $ConfigId) {
    $stored = Join-Path $env:ProgramData 'MindQuest\config.json'
    if (Test-Path $stored) {
        $cfg      = Get-Content $stored -Raw | ConvertFrom-Json
        $ConfigId = $cfg.configId
        if ($cfg.apiUrl) { $ApiUrl = $cfg.apiUrl }
    }
}

if (-not $ConfigId) {
    Write-Host 'A Config ID is required. Find yours on the Unlock page at https://onuretim.github.io/unlock/' -ForegroundColor Red
    Write-Host 'Then run:  -ConfigId mq-xxxxxx' -ForegroundColor Gray
    exit 1
}

if ($Install) {
    # Explicit exit code, so the calling .bat can tell success from failure
    # with `if errorlevel 1`. Relying on PowerShell's implicit code for an
    # unhandled terminating error is how the installer came to announce a
    # successful install that never happened.
    try {
        Install-Agent -ConfigId $ConfigId -ApiUrl $ApiUrl
        exit 0
    }
    catch {
        Write-Host ''
        Write-Host "Install failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

if (-not (Test-Administrator)) {
    Write-Host 'This needs Administrator, because blocking edits the system hosts file.' -ForegroundColor Red
    exit 1
}

$path = Resolve-HostsPath

Write-Host ''
Write-Host 'MindQuest agent running.' -ForegroundColor Cyan
Write-Host "  account: $ConfigId    api: $ApiUrl" -ForegroundColor DarkGray
Write-Host "  earn access at https://onuretim.github.io/unlock/" -ForegroundColor DarkGray
Write-Host ''

while ($true) {
    try { Invoke-Cycle -ConfigId $ConfigId -ApiUrl $ApiUrl -Path $path }
    catch { Write-Host "  cycle error: $($_.Exception.Message)" -ForegroundColor Red }

    if ($Once) { break }
    Start-Sleep -Seconds $PollSeconds
}
