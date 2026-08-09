[CmdletBinding()]
param(
    [string] $ArchiveDirectory = 'out/downloads/texlive-2020-final',
    [string] $SourceDirectory = 'out/latex-source',
    [string] $Destination = 'out/latex-runtime',
    [switch] $Offline,
    [switch] $AcquireOnly
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$lockPath = Join-Path $repositoryRoot 'third_party/latex/sources.lock'
$licenseLockPath = Join-Path $repositoryRoot 'third_party/latex/license-sources.lock'
$copyrightPath = Join-Path $repositoryRoot 'third_party/latex/COPYRIGHTS.md'
$manifestPath = Join-Path $repositoryRoot 'third_party/latex/runtime-manifest.txt'
$archiveRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $ArchiveDirectory))
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $SourceDirectory))
$runtimeRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $Destination))
$baseUrl = 'https://pi.kwarc.info/historic/systems/texlive/2020/tlnet-final/archive'

foreach ($path in $archiveRoot, $sourceRoot, $runtimeRoot) {
    if (-not $path.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "LaTeX acquisition path escapes the repository: $path"
    }
}

$sources = Get-Content -LiteralPath $lockPath |
    Where-Object { $_ -and -not $_.StartsWith('#') } |
    ConvertFrom-Csv -Delimiter '|' -Header name, revision, version, license, sha256
if (@($sources).Count -ne 50) {
    throw "Expected 50 pinned TeX Live packages, found $(@($sources).Count)"
}
$licenseSources = Get-Content -LiteralPath $licenseLockPath |
    Where-Object { $_ -and -not $_.StartsWith('#') } |
    ConvertFrom-Csv -Delimiter '|' -Header archive, sha256
if (@($licenseSources).Count -ne 4) {
    throw "Expected 4 pinned license archives, found $(@($licenseSources).Count)"
}

New-Item -ItemType Directory -Force -Path $archiveRoot | Out-Null
foreach ($source in $sources) {
    $archiveName = '{0}.r{1}.tar.xz' -f $source.name, $source.revision
    $archivePath = Join-Path $archiveRoot $archiveName
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        if ($Offline) { throw "Offline archive is missing: $archivePath" }
        Invoke-WebRequest -UseBasicParsing "$baseUrl/$archiveName" -OutFile $archivePath
    }
    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $source.sha256) {
        throw "SHA-256 mismatch for $archiveName`: expected $($source.sha256), got $actualHash"
    }
}
foreach ($source in $licenseSources) {
    $archivePath = Join-Path $archiveRoot $source.archive
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        if ($Offline) { throw "Offline license archive is missing: $archivePath" }
        Invoke-WebRequest -UseBasicParsing "$baseUrl/$($source.archive)" -OutFile $archivePath
    }
    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $source.sha256) {
        throw "SHA-256 mismatch for $($source.archive)`: expected $($source.sha256), got $actualHash"
    }
}

if ($AcquireOnly) {
    [pscustomobject]@{
        Packages = @($sources).Count
        LicenseArchives = @($licenseSources).Count
        ArchiveDirectory = $archiveRoot
    }
    return
}

foreach ($path in $sourceRoot, $runtimeRoot) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $path | Out-Null
}

$tar = Get-Command tar.exe, tar -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $tar) { throw 'A tar implementation that supports xz archives is required' }
foreach ($source in $sources) {
    $archiveName = '{0}.r{1}.tar.xz' -f $source.name, $source.revision
    & $tar.Source -xf (Join-Path $archiveRoot $archiveName) -C $sourceRoot
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $archiveName" }
}
foreach ($source in $licenseSources) {
    & $tar.Source -xf (Join-Path $archiveRoot $source.archive) -C $sourceRoot
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $($source.archive)" }
}

$manifest = Get-Content -LiteralPath $manifestPath |
    Where-Object { $_ -and -not $_.StartsWith('#') }
foreach ($entry in $manifest) {
    $parts = $entry -split '\|', 2
    if ($parts.Count -ne 2) { throw "Invalid runtime manifest entry: $entry" }
    $sourcePath = Join-Path $sourceRoot ($parts[0].Replace('/', [IO.Path]::DirectorySeparatorChar))
    $destinationPath = Join-Path $runtimeRoot ($parts[1].Replace('/', [IO.Path]::DirectorySeparatorChar))
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Runtime source file is missing: $($parts[0])"
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destinationPath) | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath
}

function Replace-Exact {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Old,
        [Parameter(Mandatory)] [string] $New,
        [Parameter(Mandatory)] [int] $ExpectedCount
    )
    $text = Get-Content -LiteralPath $Path -Raw
    $count = ([regex]::Matches($text, [regex]::Escape($Old))).Count
    if ($count -ne $ExpectedCount) {
        throw "Patch precondition failed for $Path`: expected $ExpectedCount occurrence(s), found $count"
    }
    Set-Content -LiteralPath $Path -Value $text.Replace($Old, $New) -NoNewline -Encoding ascii
}

$latexDirectory = Join-Path $runtimeRoot 'prote/latex'
$latexKernel = Join-Path $latexDirectory 'latex.ltx'
Replace-Exact $latexKernel '\def\fmtname{LaTeX2e}' `
    "\def\fmtname{LaTeX2e}`n\def\KerTeXProte{1}" 1
Replace-Exact $latexKernel '\openin\@inputcheck"#1"' '\openin\@inputcheck#1' 2

$expl3 = Join-Path $latexDirectory 'expl3-code.tex'
Replace-Exact $expl3 "  \ifnum0%`n    \expandafter\ifx\csname pdfstrcmp\endcsname\relax" `
    "  \ifnum0%`n    \ifdefined\KerTeXProte 1\fi`n    \expandafter\ifx\csname pdfstrcmp\endcsname\relax" 1

$iftex = Join-Path $latexDirectory 'iftex.sty'
Replace-Exact $iftex @'
\expandafter\ifx\csname pdftexversion\endcsname\relax
  \IFTEX@let{pdftex}{false}
\else
'@ @'
\expandafter\ifx\csname pdftexversion\endcsname\relax
  \expandafter\ifx\csname KerTeXProte\endcsname\relax
    \IFTEX@let{pdftex}{false}
  \else
    \IFTEX@let{pdftex}{true}
  \fi
\else
'@ 1

$hyphenConfig = Join-Path $latexDirectory 'hyphen.cfg'
$hyphenText = Get-Content -LiteralPath $hyphenConfig -Raw
$hyphenPattern = '(?s)\\openin1 = language\.dat.*?\\closein1'
if (([regex]::Matches($hyphenText, $hyphenPattern)).Count -ne 1) {
    throw 'Could not locate the Babel language.dat loading block'
}
$hyphenReplacement = @'
\def\languagename{english}%
\input hyphen.tex\relax
\chardef\l@english\z@
'@
Set-Content -LiteralPath $hyphenConfig `
    -Value ([regex]::Replace($hyphenText, $hyphenPattern, $hyphenReplacement)) `
    -NoNewline -Encoding ascii

$protePool = Join-Path $repositoryRoot 'out/generated/runtime/pool/prote.pool'
if (-not (Test-Path -LiteralPath $protePool -PathType Leaf)) {
    throw "Generate kerTeX sources before assembling the LaTeX runtime: $protePool"
}
$poolDirectory = Join-Path $runtimeRoot 'pool'
New-Item -ItemType Directory -Force -Path $poolDirectory | Out-Null
$latexPool = Join-Path $poolDirectory 'latex.pool'
Copy-Item -LiteralPath $protePool -Destination $latexPool
Replace-Exact $latexPool '05.dgst' '04.fmt' 1

Set-Content -LiteralPath (Join-Path $runtimeRoot 'prote/KXPATH') -Value 'latex' -Encoding ascii
Set-Content -LiteralPath (Join-Path $runtimeRoot 'fonts/KXPATH') -Value 'latex;tfm' -Encoding ascii

$licenseDirectory = Join-Path $runtimeRoot 'licenses/latex'
New-Item -ItemType Directory -Force -Path $licenseDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceRoot 'tex/latex/base/lppl.tex') -Destination $licenseDirectory
Copy-Item -LiteralPath (Join-Path $sourceRoot 'doc/fonts/amsfonts/OFL.txt') -Destination $licenseDirectory
Copy-Item -LiteralPath (Join-Path $sourceRoot 'doc/fonts/amsfonts/README') `
    -Destination (Join-Path $licenseDirectory 'README-AMSFonts.txt')
foreach ($name in 'GUST-FONT-LICENSE.TXT', 'README-Latin-Modern.TXT',
        'MANIFEST-Latin-Modern.TXT') {
    Copy-Item -LiteralPath (Join-Path $sourceRoot "doc/fonts/lm/$name") -Destination $licenseDirectory
}
Copy-Item -LiteralPath (Join-Path $sourceRoot 'doc/fonts/cm/README') `
    -Destination (Join-Path $licenseDirectory 'README-Computer-Modern.txt')
Copy-Item -LiteralPath (Join-Path $sourceRoot 'doc/fonts/ec/copyrite.txt') `
    -Destination (Join-Path $licenseDirectory 'COPYRIGHT-EC-Fonts.txt')
Copy-Item -LiteralPath (Join-Path $sourceRoot 'doc/fonts/ec/00files.txt') `
    -Destination (Join-Path $licenseDirectory 'MANIFEST-EC-Fonts.txt')
Copy-Item -LiteralPath $lockPath -Destination $licenseDirectory
Copy-Item -LiteralPath $licenseLockPath -Destination $licenseDirectory
Copy-Item -LiteralPath $manifestPath -Destination $licenseDirectory
Copy-Item -LiteralPath $copyrightPath -Destination $licenseDirectory

$expected = @($manifest | ForEach-Object { ($_ -split '\|', 2)[1] }) + @(
    'pool/latex.pool', 'prote/KXPATH', 'fonts/KXPATH',
    'licenses/latex/lppl.tex', 'licenses/latex/sources.lock',
    'licenses/latex/license-sources.lock', 'licenses/latex/runtime-manifest.txt',
    'licenses/latex/COPYRIGHTS.md', 'licenses/latex/OFL.txt',
    'licenses/latex/README-AMSFonts.txt',
    'licenses/latex/README-Computer-Modern.txt',
    'licenses/latex/COPYRIGHT-EC-Fonts.txt',
    'licenses/latex/MANIFEST-EC-Fonts.txt',
    'licenses/latex/GUST-FONT-LICENSE.TXT',
    'licenses/latex/README-Latin-Modern.TXT',
    'licenses/latex/MANIFEST-Latin-Modern.TXT'
)
$actual = @(Get-ChildItem -LiteralPath $runtimeRoot -Recurse -File | ForEach-Object {
    $_.FullName.Substring($runtimeRoot.Length + 1).Replace('\', '/')
})
$missing = @($expected | Where-Object { $_ -notin $actual })
$unexpected = @($actual | Where-Object { $_ -notin $expected })
if ($missing -or $unexpected) {
    throw "Assembled runtime inventory mismatch. Missing: $($missing -join ', '); unexpected: $($unexpected -join ', ')"
}

[pscustomobject]@{
    Packages = @($sources).Count
    LicenseArchives = @($licenseSources).Count
    ManifestFiles = @($manifest).Count
    RuntimeFiles = @($actual).Count
    Destination = $runtimeRoot
}
