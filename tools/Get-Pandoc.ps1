[CmdletBinding()]
param(
    [string] $Destination = 'out/tools/pandoc-3.10.1',
    [string] $DownloadDirectory = 'out/downloads/test-tools',
    [switch] $Offline
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$destinationPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $Destination))
$downloadPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $DownloadDirectory))
$lock = Get-Content -LiteralPath (Join-Path $repositoryRoot 'third_party/test-tools.lock') |
    Where-Object { $_ -like 'pandoc-windows-x64|*' } |
    ConvertFrom-Csv -Delimiter '|' -Header name, version, url, sha256
if (@($lock).Count -ne 1) { throw 'The pinned Pandoc tool entry is missing or duplicated.' }
$archive = Join-Path $downloadPath 'pandoc-3.10.1-windows-x86_64.zip'
New-Item -ItemType Directory -Force -Path $downloadPath | Out-Null
if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
    if ($Offline) { throw "Offline Pandoc archive is missing: $archive" }
    Invoke-WebRequest -UseBasicParsing $lock.url -OutFile $archive
}
$actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $lock.sha256) { throw "Pandoc SHA-256 mismatch: $actualHash" }
if (Test-Path -LiteralPath $destinationPath) {
    Remove-Item -LiteralPath $destinationPath -Recurse -Force
}
$temporary = Join-Path $downloadPath 'pandoc-extract'
if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force }
Expand-Archive -LiteralPath $archive -DestinationPath $temporary
$pandoc = Get-ChildItem -LiteralPath $temporary -Recurse -Filter pandoc.exe -File |
    Select-Object -First 1
if (-not $pandoc) { throw 'Pinned Pandoc archive did not contain pandoc.exe.' }
New-Item -ItemType Directory -Force -Path $destinationPath | Out-Null
Copy-Item -Path (Join-Path $pandoc.DirectoryName '*') -Destination $destinationPath -Recurse
Remove-Item -LiteralPath $temporary -Recurse -Force
$pandocPath = Join-Path $destinationPath 'pandoc.exe'
$versionOutput = @(& $pandocPath --version)
if ($LASTEXITCODE -ne 0) { throw "Pinned Pandoc version check failed with exit code $LASTEXITCODE." }
if (-not $versionOutput) { throw 'Pinned Pandoc version check returned no output.' }
$version = ([string] $versionOutput[0]).Trim()
if ($version -ne 'pandoc 3.10.1') { throw "Unexpected Pandoc version: $version" }
$pandocPath
