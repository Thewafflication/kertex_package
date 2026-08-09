[CmdletBinding()]
param(
    [string] $Destination = 'out/downloads/kertex_bundle.tar'
)

$ErrorActionPreference = 'Stop'
$url = 'https://downloads.kergis.com/kertex/kertex_bundle.tar'
$expected = 'EE42DEB024636963B9AB2322F3FC7EBE04710FF23B7F73B41C880F71E26A1CE5'
$parent = Split-Path -Parent $Destination
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

if (Test-Path -LiteralPath $Destination -PathType Leaf) {
    $actual = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if ($actual -eq $expected) {
        Write-Host "Using verified kerTeX bundle at $Destination"
        return
    }
    Write-Host "Replacing stale kerTeX bundle with SHA-256 $actual"
}

$temporary = "$Destination.download"
try {
    $curl = Get-Command curl.exe, curl -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($curl) {
        & $curl.Source --fail --location --silent --show-error --proto '=https' --tlsv1.2 `
            --retry 3 --retry-all-errors --output $temporary $url
        if ($LASTEXITCODE -ne 0) {
            throw "curl failed to download the kerTeX bundle with exit code $LASTEXITCODE"
        }
    }
    else {
        Invoke-WebRequest -UseBasicParsing $url -OutFile $temporary
    }
    $actual = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash
    if ($actual -ne $expected) {
        throw "Downloaded bundle has SHA-256 $actual; expected $expected"
    }
    Move-Item -LiteralPath $temporary -Destination $Destination -Force
    Write-Host "Downloaded and verified $Destination"
} finally {
    Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
}
