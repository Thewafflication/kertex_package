[CmdletBinding()]
param(
    [string] $Destination = 'out/tools/ghostscript-10.07.1',
    [string] $DownloadDirectory = 'out/downloads/test-tools',
    [switch] $Offline
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$destinationPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $Destination))
$downloadPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $DownloadDirectory))
$lock = Get-Content -LiteralPath (Join-Path $repositoryRoot 'third_party/test-tools.lock') |
    Where-Object { $_ -like 'ghostscript-windows-x64|*' } |
    ConvertFrom-Csv -Delimiter '|' -Header name, version, url, sha256
if (@($lock).Count -ne 1) { throw 'The pinned Ghostscript tool entry is missing or duplicated.' }
$archive = Join-Path $downloadPath 'gs10071w64.exe'
New-Item -ItemType Directory -Force -Path $downloadPath | Out-Null
if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
    if ($Offline) { throw "Offline Ghostscript archive is missing: $archive" }
    Invoke-WebRequest -UseBasicParsing $lock.url -OutFile $archive
}
$actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $lock.sha256) { throw "Ghostscript SHA-256 mismatch: $actualHash" }
$sevenZip = Get-Command 7z.exe, 7z -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $sevenZip) { throw '7-Zip is required to extract the test-only Ghostscript installer.' }
if (Test-Path -LiteralPath $destinationPath) {
    Remove-Item -LiteralPath $destinationPath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $destinationPath | Out-Null
& $sevenZip.Source x -y "-o$destinationPath" $archive | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not extract the pinned Ghostscript tool.' }
$ghostscript = Join-Path $destinationPath 'bin/gswin64c.exe'
if (-not (Test-Path -LiteralPath $ghostscript -PathType Leaf)) {
    throw 'Extracted Ghostscript did not contain gswin64c.exe.'
}
$version = (& $ghostscript --version).Trim()
if ($version -ne '10.07.1') { throw "Unexpected Ghostscript version: $version" }
$ghostscript
