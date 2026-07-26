[CmdletBinding()]
param(
    [string] $Destination = 'out/downloads/kertex_bundle.tar'
)

$ErrorActionPreference = 'Stop'
$url = 'https://downloads.kergis.com/kertex/kertex_bundle.tar'
$expected = 'B87408CC963BE3B013BE588935861771C7ACCA011BECF2888FA9629C1B97B3B4'
$parent = Split-Path -Parent $Destination
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

if (Test-Path -LiteralPath $Destination -PathType Leaf) {
    $actual = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if ($actual -eq $expected) {
        Write-Host "Using verified kerTeX bundle at $Destination"
        return
    }
    throw "Existing bundle has SHA-256 $actual; expected $expected"
}

$temporary = "$Destination.download"
try {
    Invoke-WebRequest -UseBasicParsing $url -OutFile $temporary
    $actual = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash
    if ($actual -ne $expected) {
        throw "Downloaded bundle has SHA-256 $actual; expected $expected"
    }
    Move-Item -LiteralPath $temporary -Destination $Destination
    Write-Host "Downloaded and verified $Destination"
} finally {
    Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
}
