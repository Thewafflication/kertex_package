[CmdletBinding()]
param(
    [string] $InputTex = 'out/wsp-integration/wsp-documentation.tex',
    [string] $Latex = 'out/build/x64-release/bin/latex.exe',
    [string] $Dvitype = 'out/build/x64-release/bin/dvitype.exe',
    [string] $RuntimeRoot = 'out/latex-runtime',
    [string] $FormatRoot = 'out/build/x64-release/runtime',
    [string] $OutputDirectory = 'out/wsp-native-x64',
    [int] $Passes = 4,
    [int] $ExpectedPages = 101
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))

function Resolve-RepositoryPath([string] $Path) {
    $candidate = if ([IO.Path]::IsPathRooted($Path)) {
        [IO.Path]::GetFullPath($Path)
    }
    else {
        [IO.Path]::GetFullPath((Join-Path $repositoryRoot $Path))
    }
    $prefix = $repositoryRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path must remain below the repository root: $candidate"
    }
    return $candidate
}

if ($Passes -lt 2) { throw 'At least two LaTeX passes are required.' }
$inputPath = Resolve-RepositoryPath $InputTex
$latexPath = Resolve-RepositoryPath $Latex
$dvitypePath = Resolve-RepositoryPath $Dvitype
$runtimePath = Resolve-RepositoryPath $RuntimeRoot
$formatPath = Resolve-RepositoryPath $FormatRoot
$outputPath = Resolve-RepositoryPath $OutputDirectory
foreach ($required in $inputPath, $latexPath, $dvitypePath, $runtimePath, $formatPath) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Required path does not exist: $required" }
}

if (Test-Path -LiteralPath $outputPath) {
    $resolvedOutput = (Resolve-Path -LiteralPath $outputPath).Path
    if (-not $resolvedOutput.StartsWith(
            $repositoryRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clear output outside the repository: $resolvedOutput"
    }
    Remove-Item -LiteralPath $resolvedOutput -Recurse -Force
}
New-Item -ItemType Directory -Path $outputPath | Out-Null
$localTex = Join-Path $outputPath 'wsp-documentation.tex'
Copy-Item -LiteralPath $inputPath -Destination $localTex

$savedEnvironment = @{}
foreach ($name in 'FORCE_SOURCE_DATE', 'SOURCE_DATE_EPOCH', 'KERTEX_LIBDIR',
        'KERTEX_BINDIR', 'KERTEXDUMP') {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
[Environment]::SetEnvironmentVariable('FORCE_SOURCE_DATE', '1', 'Process')
[Environment]::SetEnvironmentVariable('SOURCE_DATE_EPOCH', 'D:20260101000000Z', 'Process')
[Environment]::SetEnvironmentVariable('KERTEX_LIBDIR', $runtimePath, 'Process')
[Environment]::SetEnvironmentVariable('KERTEX_BINDIR', $formatPath, 'Process')
[Environment]::SetEnvironmentVariable('KERTEXDUMP', (Join-Path $formatPath 'lib'), 'Process')

try {
    Push-Location $outputPath
    try {
        for ($pass = 1; $pass -le $Passes; $pass++) {
            $timer = [Diagnostics.Stopwatch]::StartNew()
            $transcript = & $latexPath 'wsp-documentation.tex' 2>&1
            $exitCode = $LASTEXITCODE
            $timer.Stop()
            $transcript | Set-Content -LiteralPath "pass-$pass.stdout.txt" -Encoding utf8
            if ($exitCode -ne 0) {
                throw "Native LaTeX pass $pass failed with exit code $exitCode. See pass-$pass.stdout.txt."
            }
            Write-Host "Native LaTeX pass $pass/$Passes completed in $([math]::Round($timer.Elapsed.TotalSeconds, 1)) seconds."
        }

        $log = Get-Content -LiteralPath 'wsp-documentation.log' -Raw
        foreach ($pattern in @(
                '(?m)^! ', 'Undefined control sequence', 'LaTeX Error:',
                'Metric \(TFM\) file not found', 'File .* not found', 'not loadable',
                'Missing character:', 'undefined references',
                'Label\(s\) may have changed', 'Rerun to get', 'MiKTeX',
                'texlive', 'texmf-dist')) {
            if ($log -match $pattern) {
                throw "Final WSP LaTeX transcript contains forbidden pattern: $pattern"
            }
        }

        $dvi = Join-Path $outputPath 'wsp-documentation.dvi'
        if (-not (Test-Path -LiteralPath $dvi -PathType Leaf) -or
            (Get-Item -LiteralPath $dvi).Length -lt 100000) {
            throw 'Native LaTeX did not create a substantial WSP DVI.'
        }
        if ($log -notmatch "Output written on wsp-documentation\.dvi \($ExpectedPages pages?,") {
            throw "Native WSP page count did not match the expected $ExpectedPages pages."
        }

        Set-Content -LiteralPath 'dvitype.in' -Value "0`n*`n1000000`n300/1`n0" -Encoding ascii
        $process = Start-Process -FilePath $dvitypePath -ArgumentList $dvi `
            -RedirectStandardInput 'dvitype.in' -RedirectStandardOutput 'dvitype.out' `
            -RedirectStandardError 'dvitype.err' -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "Packaged dvitype rejected the WSP DVI; see dvitype.err."
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
    }
}

[pscustomobject]@{
    Dvi = Join-Path $outputPath 'wsp-documentation.dvi'
    Pages = $ExpectedPages
    Passes = $Passes
    Bytes = (Get-Item -LiteralPath (Join-Path $outputPath 'wsp-documentation.dvi')).Length
}
