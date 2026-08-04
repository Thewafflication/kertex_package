[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $InstallRoot
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($InstallRoot)
$bin = Join-Path $root 'bin'
$expectedExecutables = @(
    'afm2tfm.exe', 'bibtex.exe', 'ctangle.exe', 'cweave.exe', 'cwmerge.exe',
    'dmp.exe', 'dvips.exe', 'dvitomp.exe', 'dvitype.exe', 'einitex.exe',
    'evirtex.exe', 'gftodvi.exe', 'gftopk.exe', 'gftype.exe', 'inimf.exe',
    'inimp.exe', 'iniprote.exe', 'initex.exe', 'mft.exe', 'mptotex.exe',
    'mptotr.exe', 'pltotf.exe', 'pooltype.exe', 'tangle.exe', 'tex.exe',
    'tftopl.exe', 'vftovp.exe', 'virmf.exe', 'virmp.exe', 'virprote.exe',
    'virtex.exe', 'vptovf.exe', 'weave.exe'
)
$actualExecutables = @(
    Get-ChildItem -LiteralPath $bin -Filter '*.exe' -File |
        Select-Object -ExpandProperty Name |
        Sort-Object
)
$missingExecutables = @($expectedExecutables | Where-Object { $_ -notin $actualExecutables })
$unexpectedExecutables = @($actualExecutables | Where-Object { $_ -notin $expectedExecutables })
if ($missingExecutables -or $unexpectedExecutables) {
    throw "Native executable inventory mismatch. Missing: $($missingExecutables -join ', '); unexpected: $($unexpectedExecutables -join ', ')"
}

$requiredDumps = 'plain.fmt', 'plain.base', 'plain.mem'
$missingDumps = @(
    $requiredDumps | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $bin "lib\$_") -PathType Leaf)
    }
)
if ($missingDumps) {
    throw "Native format inventory is missing: $($missingDumps -join ', ')"
}

[pscustomobject]@{
    InstallRoot = $root
    Executables = $actualExecutables.Count
    Formats = $requiredDumps.Count
}
