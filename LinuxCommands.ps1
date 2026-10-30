# Dot-source this from a PowerShell profile.
# PowerShell aliases such as ls and rm point at cmdlets, so Unix flags
# never reach a real program. This puts the real programs first and
# removes only the aliases that were hiding them.

$__lxCmd = 'C:\Program Files\coreutils\cmd'
$__lxBin = 'C:\Program Files\coreutils\bin'
$__lxGit = 'C:\Program Files\Git\usr\bin'

if (Test-Path -LiteralPath $__lxCmd) {
    $__lxPrefer = $__lxCmd
} elseif (Test-Path -LiteralPath $__lxBin) {
    $__lxPrefer = $__lxBin
} else {
    $__lxPrefer = $null
}

$__lxParts = @($env:PATH -split ';' | Where-Object { $_ })

if ($__lxPrefer) {
    $__lxPreferKey = $__lxPrefer.TrimEnd('\')
    $__lxParts = @($__lxParts | Where-Object { $_.TrimEnd('\') -ine $__lxPreferKey })
    $env:PATH = ((@($__lxPrefer) + $__lxParts) -join ';')
    $__lxParts = @($env:PATH -split ';' | Where-Object { $_ })
}

if (Test-Path -LiteralPath $__lxGit) {
    $__lxGitKey = $__lxGit.TrimEnd('\')
    $__lxParts = @($__lxParts | Where-Object { $_.TrimEnd('\') -ine $__lxGitKey })
    $env:PATH = (($__lxParts + @($__lxGit)) -join ';')
}

# cd, dir, where, ps, kill, and clear stay PowerShell commands.
# An external cd cannot change this shell's directory, and where is Where-Object.
$__lxNames = @(
    'cat', 'cp', 'curl', 'diff', 'echo', 'ls', 'mkdir', 'mv', 'pwd',
    'rm', 'rmdir', 'sleep', 'sort', 'tee', 'wget'
)

foreach ($__lxName in $__lxNames) {
    $__lxApp = Get-Command -Name $__lxName -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $__lxApp) {
        continue
    }

    foreach ($__lxKind in @('Alias', 'Function')) {
        $__lxPath = "${__lxKind}:$__lxName"
        if (Test-Path -LiteralPath $__lxPath) {
            Remove-Item -LiteralPath $__lxPath -Force -ErrorAction SilentlyContinue
        }
    }
}

Remove-Variable -Name __lxCmd, __lxBin, __lxGit, __lxPrefer, __lxPreferKey, __lxGitKey, __lxParts, __lxNames, __lxName, __lxApp, __lxKind, __lxPath -ErrorAction SilentlyContinue
