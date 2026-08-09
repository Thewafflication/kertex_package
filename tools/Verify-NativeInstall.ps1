[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $InstallRoot,

    [Parameter(Mandatory)]
    [ValidateSet('x86', 'x64', 'arm64')]
    [string] $Architecture
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($InstallRoot)
$bin = Join-Path $root 'bin'
$expectedExecutables = @(
    'afm2tfm.exe', 'bibtex.exe', 'ctangle.exe', 'cweave.exe', 'cwmerge.exe',
    'dmp.exe', 'dvips.exe', 'dvitomp.exe', 'dvitype.exe', 'einitex.exe',
    'evirtex.exe', 'gftodvi.exe', 'gftopk.exe', 'gftype.exe', 'inimf.exe',
    'inimp.exe', 'iniprote.exe', 'initex.exe', 'mft.exe', 'mptotex.exe',
    'mptotr.exe', 'latex.exe', 'pltotf.exe', 'pooltype.exe', 'tangle.exe', 'tex.exe',
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

$requiredDumps = 'plain.fmt', 'plain.base', 'plain.mem', 'latex.fmt'
$missingDumps = @(
    $requiredDumps | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $bin "lib\$_") -PathType Leaf)
    }
)
if ($missingDumps) {
    throw "Native format inventory is missing: $($missingDumps -join ', ')"
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$runtimeManifestPath = Join-Path $repositoryRoot 'third_party/latex/runtime-manifest.txt'
$runtimeManifest = Get-Content -LiteralPath $runtimeManifestPath |
    Where-Object { $_ -and -not $_.StartsWith('#') }
$shareRoot = Join-Path $root 'share/kertex'
$missingRuntime = foreach ($entry in $runtimeManifest) {
    $destination = ($entry -split '\|', 2)[1]
    $installedPath = Join-Path $shareRoot ($destination.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $installedPath -PathType Leaf)) { $destination }
}
if ($missingRuntime) {
    throw "Pinned LaTeX runtime is incomplete: $($missingRuntime -join ', ')"
}

$requiredRuntimeFiles = @(
    'pool/latex.pool', 'prote/KXPATH', 'fonts/KXPATH',
    'licenses/latex/lppl.tex', 'licenses/latex/OFL.txt',
    'licenses/latex/GUST-FONT-LICENSE.TXT',
    'licenses/latex/README-AMSFonts.txt',
    'licenses/latex/README-Computer-Modern.txt',
    'licenses/latex/COPYRIGHT-EC-Fonts.txt',
    'licenses/latex/MANIFEST-EC-Fonts.txt',
    'licenses/latex/README-Latin-Modern.TXT',
    'licenses/latex/MANIFEST-Latin-Modern.TXT',
    'licenses/latex/COPYRIGHTS.md', 'licenses/latex/sources.lock',
    'licenses/latex/license-sources.lock',
    'licenses/latex/runtime-manifest.txt'
)
$missingSupport = @($requiredRuntimeFiles | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $shareRoot $_) -PathType Leaf)
})
if ($missingSupport) {
    throw "LaTeX runtime support inventory is incomplete: $($missingSupport -join ', ')"
}
if ((Get-Content -LiteralPath (Join-Path $shareRoot 'prote/KXPATH') -Raw).Trim() -ne 'latex' -or
    (Get-Content -LiteralPath (Join-Path $shareRoot 'fonts/KXPATH') -Raw).Trim() -ne 'latex;tfm') {
    throw 'Installed KerTeX KXPATH files do not describe the pinned LaTeX tree.'
}

$formatPath = Join-Path $bin 'lib/latex.fmt'
$provenancePath = Join-Path $bin 'lib/latex.fmt.provenance'
if (-not (Test-Path -LiteralPath $provenancePath -PathType Leaf)) {
    throw 'Native LaTeX format provenance is missing.'
}
$provenance = @{}
Get-Content -LiteralPath $provenancePath | ForEach-Object {
    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) { $provenance[$parts[0]] = $parts[1] }
}
if ($provenance.architecture -ne $Architecture) {
    throw "LaTeX format architecture mismatch: expected $Architecture, recorded $($provenance.architecture)"
}
$formatHash = (Get-FileHash -LiteralPath $formatPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($provenance['format-sha256'] -ne $formatHash) {
    throw 'LaTeX format SHA-256 does not match its architecture provenance.'
}
$formatText = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($formatPath))
if ($formatText -match '(?i)[a-z]:[\\/](users|build|runner|agent)[\\/]' -or
    $formatText -match '(?i)/(home|mnt|tmp)/(runner|agent|[^/]+)/(work|source|repos)/') {
    throw 'LaTeX format contains an absolute generator-machine path.'
}

[pscustomobject]@{
    InstallRoot = $root
    Executables = $actualExecutables.Count
    Formats = $requiredDumps.Count
    LatexRuntimeFiles = @($runtimeManifest).Count
    LatexFormatSha256 = $formatHash
}
