[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $InstallRoot,

    [Parameter(Mandatory)]
    [ValidateSet('x86', 'x64', 'arm64')]
    [string] $Architecture,

    [string] $OutputDirectory = "out/install-smoke"
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$installPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $InstallRoot))
$outputPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot "$OutputDirectory/$Architecture"))
$cmake = Get-Command cmake.exe, cmake -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $cmake) {
    $fallback = 'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
    if (-not (Test-Path -LiteralPath $fallback -PathType Leaf)) { throw 'cmake was not found.' }
    $cmakePath = $fallback
}
else { $cmakePath = $cmake.Source }

$arguments = @(
    "-DKERTEX_LATEX=$(Join-Path $installPath 'bin/latex.exe')"
    "-DKERTEX_DVITYPE=$(Join-Path $installPath 'bin/dvitype.exe')"
    "-DKERTEX_RUNTIME_ROOT=$(Join-Path $installPath 'share/kertex')"
    "-DKERTEX_FORMAT_ROOT=$(Join-Path $installPath 'bin')"
    "-DKERTEX_TEST_INPUT=$(Join-Path $repositoryRoot 'cmake/latex-smoke.tex')"
    "-DKERTEX_TEST_DIR=$outputPath"
    '-P'
    (Join-Path $repositoryRoot 'cmake/LatexSmoke.cmake')
)
& $cmakePath @arguments
if ($LASTEXITCODE -ne 0) { throw "Installed LaTeX smoke failed for $Architecture." }

$log = Get-Content -LiteralPath (Join-Path $outputPath 'latex-smoke.log') -Raw
$normalizedInstall = $installPath.Replace('\', '/')
$normalizedLog = ($log -replace '\\', '/') -replace '\s+', ''
if ($normalizedLog -notlike "*$normalizedInstall*") {
    throw 'Installed LaTeX smoke did not record reads from its staged install tree.'
}
if ($log -match '(?i)(miktex|texlive|texmf-dist)') {
    throw 'Installed LaTeX smoke attempted to use a system TeX distribution.'
}

[pscustomobject]@{
    Architecture = $Architecture
    InstallRoot = $installPath
    Dvi = Join-Path $outputPath 'latex-smoke.dvi'
}
