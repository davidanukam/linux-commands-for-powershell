$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'LinuxCommands.ps1')

function Assert-Match {
    param([string]$Value, [string]$Pattern, [string]$Label)
    if ($Value -notmatch $Pattern) {
        throw "$Label expected /$Pattern/ but got: [$Value]"
    }
}

function Assert-Source {
    param([string]$Name, [string]$Pattern)
    $cmd = Get-Command $Name -ErrorAction Stop
    if ($cmd.Source -notlike $Pattern) {
        throw "$Name resolved to $($cmd.CommandType) $($cmd.Source)"
    }
}

Assert-Source ls '*\coreutils\cmd\ls.cmd'
Assert-Source grep '*\coreutils\cmd\grep.cmd'
Assert-Source find '*\coreutils\cmd\find.cmd'
Assert-Source sort '*\coreutils\cmd\sort.cmd'
Assert-Source curl '*\curl.exe'
Assert-Source diff '*\Git\usr\bin\diff.exe'
Assert-Source sed '*\sed.exe'
Assert-Source awk '*\awk.exe'

$where = Get-Command where
if ($where.CommandType -ne 'Alias' -or $where.Definition -ne 'Where-Object') {
    throw "where should stay Where-Object, got $($where.CommandType) $($where.Definition)"
}
$cd = Get-Command cd
if ($cd.Definition -ne 'Set-Location') {
    throw "cd should stay Set-Location, got $($cd.Definition)"
}

$root = Join-Path $env:TEMP ('lx-' + [guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $root | Out-Null
try {
    $nested = Join-Path $root 'a\b'
    & mkdir -p $nested
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $nested)) {
        throw "mkdir -p failed (exit $LASTEXITCODE)"
    }

    $file = Join-Path $nested 'notes.txt'
    & touch $file
    if (-not (Test-Path -LiteralPath $file)) {
        throw 'touch did not create the file'
    }

    [System.IO.File]::WriteAllText($file, "alpha`nbeta`ngamma`n")
    $listed = (& ls -la --color=never $nested | Out-String)
    Assert-Match $listed 'notes\.txt' 'ls -la'

    $grep = (& grep -n 'beta' $file | Out-String).Trim()
    Assert-Match $grep '^2:beta' 'grep -n'

    $head = (& head -n 1 $file | Out-String).Trim()
    Assert-Match $head '^alpha$' 'head -n'

    $tail = (& tail -n 1 $file | Out-String).Trim()
    Assert-Match $tail '^gamma$' 'tail -n'

    $wc = (& wc -l $file | Out-String).Trim()
    Assert-Match $wc '^3\b' 'wc -l'

    $cutFile = Join-Path $nested 'row.txt'
    [System.IO.File]::WriteAllText($cutFile, "a,b,c`n")
    $cut = (& cut -d ',' -f 2 $cutFile | Out-String).Trim()
    Assert-Match $cut '^b$' 'cut -d'

    $sorted = Join-Path $nested 'sorted.txt'
    [System.IO.File]::WriteAllText($sorted, "b`na`nb`n")
    $unique = (& sort -u $sorted | Out-String).Trim()
    Assert-Match $unique '(?s)^a\s+b$' 'sort -u'

    $sed = (& sed -n '2p' $file | Out-String).Trim()
    Assert-Match $sed '^beta$' 'sed -n'

    $awk = (& awk 'NR==2 { print }' $file | Out-String).Trim()
    Assert-Match $awk '^beta$' 'awk'

    $copy = Join-Path $nested 'copy.txt'
    & cp $file $copy
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $copy)) {
        throw "cp failed (exit $LASTEXITCODE)"
    }

    $moved = Join-Path $root 'moved.txt'
    & mv $copy $moved
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $moved)) {
        throw "mv failed (exit $LASTEXITCODE)"
    }

    $left = Join-Path $root 'left.txt'
    $right = Join-Path $root 'right.txt'
    [System.IO.File]::WriteAllText($left, "same`nold`n")
    [System.IO.File]::WriteAllText($right, "same`nnew`n")
    $diff = (& diff -u $left $right | Out-String)
    Assert-Match $diff '-old' 'diff -u'
    Assert-Match $diff '\+new' 'diff -u added'

    Push-Location $root
    try {
        $found = (& find . -name 'notes.txt' | Out-String)
    } finally {
        Pop-Location
    }
    Assert-Match $found 'notes\.txt' 'find -name'

    $base = (& basename $file | Out-String).Trim()
    Assert-Match $base '^notes\.txt$' 'basename'

    & rm -r $nested
    if ($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath $nested)) {
        throw "rm -r failed (exit $LASTEXITCODE)"
    }
} finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "ok $($PSVersionTable.PSVersion)"
