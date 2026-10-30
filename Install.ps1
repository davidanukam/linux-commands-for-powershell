# Installs Coreutils and Glow, then points the PowerShell profiles at this clone.
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1

$ErrorActionPreference = 'Stop'

$repo = $PSScriptRoot
$linuxCommands = Join-Path $repo 'LinuxCommands.ps1'
if (-not (Test-Path -LiteralPath $linuxCommands)) {
    throw "LinuxCommands.ps1 was not found next to Install.ps1."
}

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $combined = @($machine, $user) | Where-Object { $_ }
    if ($combined.Count -gt 0) {
        $env:PATH = $combined -join ';'
    }
}

function Add-UserPathEntry {
    param([string]$Entry)
    if (-not (Test-Path -LiteralPath $Entry)) {
        return
    }
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if ($userPath) {
        $parts = @($userPath -split ';' | Where-Object { $_ })
    }
    $key = $Entry.TrimEnd('\')
    foreach ($part in $parts) {
        if ($part.TrimEnd('\') -ieq $key) {
            return
        }
    }
    $updated = (@($parts) + $Entry) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $updated, 'User')
}

function Test-WingetInstalled {
    param([string]$Id)
    & winget list --id $Id -e --accept-source-agreements --disable-interactivity | Out-Null
    return $LASTEXITCODE -eq 0
}

function Install-WingetPackage {
    param([string]$Id)
    if (Test-WingetInstalled $Id) {
        Write-Host "Already installed: $Id"
        return
    }
    Write-Host "Installing $Id"
    & winget install --id $Id -e --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "winget install $Id failed with exit code $LASTEXITCODE"
    }
}

function Set-ProfileSource {
    param([string]$ProfilePath, [string]$ScriptPath)
    $directory = Split-Path -Parent $ProfilePath
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $quoted = $ScriptPath.Replace("'", "''")
    $block = "# linux-commands-for-powershell: real Unix programs, with their flags`r`n. '$quoted'"
    if (Test-Path -LiteralPath $ProfilePath) {
        $content = [System.IO.File]::ReadAllText($ProfilePath)
        $pattern = '(?m)^# linux-commands-for-powershell:.*\r?\n\. .*\r?\n?'
        if ([regex]::IsMatch($content, $pattern)) {
            $content = [regex]::Replace($content, $pattern, ($block + "`r`n"), 1)
        } else {
            if ($content.Length -gt 0 -and -not $content.EndsWith("`n")) {
                $content += "`r`n"
            }
            $content += "`r`n" + $block + "`r`n"
        }
    } else {
        $content = $block + "`r`n"
    }

    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($ProfilePath, $content, $utf8)
    Write-Host "Profile updated: $ProfilePath"
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is required. Install App Installer from the Microsoft Store, then run this script again."
}

$coreutilsReady = (Test-Path -LiteralPath 'C:\Program Files\coreutils\cmd') -or (Test-Path -LiteralPath 'C:\Program Files\coreutils\bin')
if ($coreutilsReady) {
    Write-Host 'Already installed: Microsoft.Coreutils'
} else {
    Install-WingetPackage 'Microsoft.Coreutils'
}

Update-SessionPath
Install-WingetPackage 'charmbracelet.glow'
Update-SessionPath

$glow = Get-Command glow -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $glow) {
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages')
    )
    $found = $null
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }
        $found = Get-ChildItem -LiteralPath $root -Filter glow.exe -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($found) {
            break
        }
    }
    if (-not $found) {
        throw "Glow installed, but glow.exe was not found on PATH or under $env:LOCALAPPDATA\Microsoft\WinGet."
    }
    Add-UserPathEntry $found.DirectoryName
    Update-SessionPath
    $glow = Get-Command glow -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
}

if (-not $glow) {
    throw 'glow.exe is still not on PATH. Open a new terminal and run: glow --version'
}

$documents = [Environment]::GetFolderPath('MyDocuments')
$profiles = @(
    (Join-Path $documents 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1')
)
foreach ($profilePath in $profiles) {
    Set-ProfileSource -ProfilePath $profilePath -ScriptPath $linuxCommands
}

$coreutilsPath = 'C:\Program Files\coreutils\cmd'
if (-not (Test-Path -LiteralPath $coreutilsPath)) {
    $coreutilsPath = 'C:\Program Files\coreutils\bin'
}

Write-Host ''
Write-Host "Coreutils: $coreutilsPath"
Write-Host "Glow: $($glow.Source)"
Write-Host 'Open a new PowerShell window, then run: ls -la'
Write-Host 'Read this repo in the terminal with: glow README.md'
