$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Owner        = 'ItzMeShadow999'
$Repo         = 'AlwaysAudioFiles'
$Branch       = 'main'
$PluginFolder = 'alwaysAudioFiles'
$PluginName   = 'AlwaysAudioFiles'
$PluginFiles  = @('index.tsx', 'native.ts')

function Step($m) { Write-Host ""; Write-Host "§ $m" -ForegroundColor Magenta }
function Info($m) { Write-Host "  ▸ $m" -ForegroundColor Gray }
function Ok($m)   { Write-Host "  ◆ $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  ▪ $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "  ✖ $m" -ForegroundColor Red; throw $m }

function Test-Cmd($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Refresh-Path {
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$m;$u"
}

function Run($exe, $argList) {
    & $exe @argList
    if ($LASTEXITCODE -ne 0) { Die "$exe $($argList -join ' ') failed (exit $LASTEXITCODE)" }
}

function Ensure-WingetPackage($cmd, $id, $label) {
    if (Test-Cmd $cmd) { Ok "$label found"; return }
    if (-not (Test-Cmd 'winget')) { Die "$label is missing and winget is not available. Install $label manually and re-run." }
    Info "installing $label via winget"
    & winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
    Refresh-Path
    if (-not (Test-Cmd $cmd)) { Die "$label installed but not on PATH yet. Open a new PowerShell window and re-run." }
    Ok "$label installed"
}

Write-Host ""
Write-Host "◆ $PluginName installer" -ForegroundColor Magenta
Write-Host "  Third-party plugin. Client mods are against Discord's ToS, use at your own risk." -ForegroundColor DarkGray

Step "Choose client"
$client = $env:AAF_CLIENT
if (-not $client) {
    Write-Host "  [1] Vencord"
    Write-Host "  [2] Equicord"
    $pick = Read-Host "  Select 1 or 2"
    $client = if ($pick -eq '2') { 'equicord' } else { 'vencord' }
}
switch ($client.ToLower()) {
    'vencord'  { $ClientName = 'Vencord';  $RepoUrl = 'https://github.com/Vendicated/Vencord' }
    'equicord' { $ClientName = 'Equicord'; $RepoUrl = 'https://github.com/Equicord/Equicord' }
    default    { Die "Unknown client '$client'. Use vencord or equicord." }
}
Ok $ClientName

Step "Prerequisites"
Ensure-WingetPackage 'git'  'Git.Git'           'Git'
Ensure-WingetPackage 'node' 'OpenJS.NodeJS.LTS' 'Node.js'
if (-not (Test-Cmd 'pnpm')) {
    Info "installing pnpm"
    Run 'npm' @('install', '-g', 'pnpm')
    Refresh-Path
    if (-not (Test-Cmd 'pnpm')) { Die "pnpm install failed. Run: npm install -g pnpm" }
}
Ok "pnpm found"

Step "Source"
$dir = $env:AAF_DIR
$hasSource = $false
if ($env:AAF_YES -eq '1') {
    $hasSource = [bool]($dir -and (Test-Path (Join-Path $dir 'package.json')))
} else {
    $a = Read-Host "  Do you already have $ClientName built from source (cloned from GitHub, not the installer)? [y/N]"
    $hasSource = $a -match '^(y|yes)$'
}

if ($hasSource) {
    if (-not $dir) {
        Write-Host "  Enter the path to your $ClientName folder (repo root, its src folder, or src\userplugins)" -ForegroundColor DarkGray
        $dir = Read-Host "  Path"
        if (-not $dir) { Die "No path given." }
    }
    $dir = $dir.Trim().Trim('"').TrimEnd('\', '/')
    $leaf = Split-Path $dir -Leaf
    if ($leaf -ieq 'userplugins') { $dir = Split-Path (Split-Path $dir -Parent) -Parent }
    elseif ($leaf -ieq 'src')     { $dir = Split-Path $dir -Parent }
    if (-not (Test-Path (Join-Path $dir 'package.json')) -or -not (Test-Path (Join-Path $dir 'src'))) {
        Die "$dir does not look like a $ClientName source folder (package.json or src missing)."
    }
    Ok "using existing source at $dir"
} else {
    if (-not $dir) {
        $default = Join-Path $env:USERPROFILE $ClientName
        if ($env:AAF_YES -eq '1') {
            $dir = $default
        } else {
            $dir = Read-Host "  Where should $ClientName be cloned? Enter a folder path (blank = $default)"
            if (-not $dir) { $dir = $default }
        }
    }
    $dir = $dir.Trim().Trim('"').TrimEnd('\', '/')
    if (Test-Path (Join-Path $dir '.git')) {
        Info "existing clone at $dir, pulling latest"
        Run 'git' @('-C', $dir, 'pull', '--ff-only')
    } elseif (Test-Path $dir) {
        Die "$dir exists but is not a git repo. Set `$env:AAF_DIR to another path or remove it."
    } else {
        Info "cloning $ClientName into $dir"
        Run 'git' @('clone', $RepoUrl, $dir)
    }
    Ok $dir
}

Step "Plugin files"
$pluginDir = Join-Path $dir "src\userplugins\$PluginFolder"
New-Item -ItemType Directory -Force -Path $pluginDir | Out-Null
foreach ($file in $PluginFiles) {
    $url = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch/$file"
    Invoke-WebRequest -Uri $url -OutFile (Join-Path $pluginDir $file) -UseBasicParsing
    Ok "$file copied to $pluginDir"
}

Step "Discord"
$procs = Get-Process -Name 'Discord', 'DiscordPTB', 'DiscordCanary', 'DiscordDevelopment' -ErrorAction SilentlyContinue
if ($procs) {
    $close = $true
    if ($env:AAF_YES -ne '1') {
        $a = Read-Host "  Discord is running. Close it now? [Y/n]"
        if ($a -match '^(n|no)$') { $close = $false }
    }
    if ($close) {
        $procs | Stop-Process -Force
        Start-Sleep -Seconds 2
        Ok "Discord closed"
    } else {
        Warn "leaving Discord open, restart it manually after inject"
    }
} else {
    Ok "Discord not running"
}

Step "Build"
Push-Location $dir
try {
    Run 'pnpm' @('install')
    Run 'pnpm' @('build')
    Ok "build complete"

    Step "Inject"
    $doInject = $true
    if ($hasSource -and $env:AAF_YES -ne '1') {
        $s = Read-Host "  Already injected into Discord? Skip inject [y/N]"
        if ($s -match '^(y|yes)$') { $doInject = $false }
    }
    if ($doInject) {
        Info "pick your Discord install when prompted"
        Run 'pnpm' @('inject')
        Ok "inject complete"
    } else {
        Ok "inject skipped"
    }
} finally {
    Pop-Location
}

Step "Enable plugin"
$settingsDir  = Join-Path $env:APPDATA "$ClientName\settings"
$settingsFile = Join-Path $settingsDir 'settings.json'
try {
    New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
    $json = if (Test-Path $settingsFile) { Get-Content $settingsFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
    if (-not $json.PSObject.Properties['plugins']) {
        $json | Add-Member -NotePropertyName plugins -NotePropertyValue ([pscustomobject]@{})
    }
    $json.plugins | Add-Member -NotePropertyName $PluginName -NotePropertyValue ([pscustomobject]@{ enabled = $true }) -Force
    $json | ConvertTo-Json -Depth 32 | Set-Content -Path $settingsFile -Encoding UTF8
    Ok "$PluginName enabled in $settingsFile"
} catch {
    Warn "could not auto-enable. Open $ClientName Settings > Plugins and enable $PluginName."
}

Step "Launch"
$update = Join-Path $env:LOCALAPPDATA 'Discord\Update.exe'
if (Test-Path $update) {
    Start-Process $update -ArgumentList '--processStart', 'Discord.exe'
    Ok "Discord launched"
} else {
    Warn "start Discord manually"
}

Write-Host ""
Write-Host "◆ Done." -ForegroundColor Magenta
Write-Host "  ▸ In Discord press Ctrl+R if the plugin does not show up yet." -ForegroundColor Gray
Write-Host ""
