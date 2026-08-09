[CmdletBinding()]
param(
    [string] $Pandoc = 'out/tools/pandoc-3.10.1/pandoc.exe',
    [Parameter(Mandatory)] [string] $PdfLatex,
    [Parameter(Mandatory)] [string] $Dvips,
    [Parameter(Mandatory)] [string] $Ghostscript,
    [Parameter(Mandatory)] [string] $Python,
    [string] $Latex = 'out/build/x64-release/bin/latex.exe',
    [string] $Dvitype = 'out/build/x64-release/bin/dvitype.exe',
    [string] $RuntimeRoot = 'out/latex-runtime',
    [string] $FormatRoot = 'out/build/x64-release/runtime',
    [string] $OutputRoot = 'out/wsp-comparison-x64'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
function Resolve-Repo([string] $Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $repositoryRoot $Path))
}
function Resolve-Tool([string] $Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return (Resolve-Path -LiteralPath $Path).Path }
    $command = Get-Command $Path -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { throw "Comparison tool was not found: $Path" }
    return $command.Source
}

$pandocPath = Resolve-Tool (Resolve-Repo $Pandoc)
$pdfLatexPath = Resolve-Tool $PdfLatex
$dvipsPath = Resolve-Tool $Dvips
$ghostscriptPath = Resolve-Tool $Ghostscript
$pythonPath = Resolve-Tool $Python
$fixture = @{}
foreach ($line in Get-Content -LiteralPath (Join-Path $repositoryRoot 'third_party/wsp-fixture.lock')) {
    if ($line -match '^([^#=]+)=(.*)$') { $fixture[$matches[1].Trim()] = $matches[2].Trim() }
}
$expectedPdfLatexVersion = $fixture['pdf-engine-version']
if (-not $expectedPdfLatexVersion) { throw 'Missing pdf-engine-version in third_party/wsp-fixture.lock.' }
$pdfLatexVersion = (& $pdfLatexPath --version | Select-Object -First 1).Trim()
if ($pdfLatexVersion -ne $expectedPdfLatexVersion) {
    throw "Reference pdfLaTeX version mismatch: expected '$expectedPdfLatexVersion', got '$pdfLatexVersion'."
}
$outputPath = Resolve-Repo $OutputRoot
$texPath = Join-Path $outputPath 'wsp-documentation.tex'
$referenceDirectory = Join-Path $outputPath 'reference'
$nativeDirectory = Join-Path $outputPath 'native'
if (Test-Path -LiteralPath $outputPath) {
    if (-not $outputPath.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clear output outside the repository: $outputPath"
    }
    Remove-Item -LiteralPath $outputPath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outputPath, $referenceDirectory | Out-Null

& (Join-Path $PSScriptRoot 'Generate-WspLatex.ps1') -Pandoc $pandocPath `
    -OutputPath $texPath -Version '0.0.0-test' -BuildDate '2026-01-01' | Out-Null
Copy-Item -LiteralPath $texPath -Destination $referenceDirectory

$savedDate = $env:SOURCE_DATE_EPOCH
$savedForce = $env:FORCE_SOURCE_DATE
$savedTimezone = $env:TZ
$env:SOURCE_DATE_EPOCH = '1767225600'
$env:FORCE_SOURCE_DATE = '1'
$env:TZ = 'UTC'
try {
    Push-Location $referenceDirectory
    try {
        foreach ($pass in 1..4) {
            # Windows PowerShell 5.1 wraps native stderr as ErrorRecord objects.
            # MiKTeX emits a harmless elevated-process warning there, so capture it
            # under Continue and use the native exit code as the authoritative gate.
            $savedErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $output = & $pdfLatexPath -interaction=nonstopmode -halt-on-error `
                    -recorder wsp-documentation.tex 2>&1
                $pdfLatexExitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $savedErrorActionPreference
            }
            $output | Set-Content -LiteralPath "pass-$pass.stdout.txt" -Encoding utf8
            if ($pdfLatexExitCode -ne 0) {
                throw "Reference pdfLaTeX pass $pass failed with exit code $pdfLatexExitCode."
            }
        }
    }
    finally { Pop-Location }
}
finally {
    $env:SOURCE_DATE_EPOCH = $savedDate
    $env:FORCE_SOURCE_DATE = $savedForce
    $env:TZ = $savedTimezone
}

& (Join-Path $PSScriptRoot 'Test-WspNativeLatex.ps1') `
    -InputTex $texPath -Latex (Resolve-Repo $Latex) -Dvitype (Resolve-Repo $Dvitype) `
    -RuntimeRoot (Resolve-Repo $RuntimeRoot) -FormatRoot (Resolve-Repo $FormatRoot) `
    -OutputDirectory $nativeDirectory -ExpectedPages 101 | Out-Null

Push-Location $nativeDirectory
try {
    $firstDvips = & $dvipsPath -Ppdf -G0 -o wsp-documentation.ps wsp-documentation.dvi 2>&1
    $firstDvips | Set-Content -LiteralPath 'dvips-pass-1.txt' -Encoding utf8
    if ($LASTEXITCODE -ne 0 -and -not (Test-Path -LiteralPath 'wsp-documentation.out.ps')) {
        throw 'The first test-only dvips pass failed before producing its pdfmark header.'
    }
    $secondDvips = & $dvipsPath -Ppdf -G0 -o wsp-documentation.ps wsp-documentation.dvi 2>&1
    $secondDvips | Set-Content -LiteralPath 'dvips-pass-2.txt' -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw 'The final test-only dvips pass failed.' }

    $gsArguments = @(
        '-q', '-dSAFER', '-dBATCH', '-dNOPAUSE', '-sDEVICE=pdfwrite',
        '-dCompatibilityLevel=1.7', '-sOutputFile=wsp-documentation-dvi.pdf',
        'wsp-documentation.ps'
    )
    $gs = Start-Process -FilePath $ghostscriptPath -ArgumentList $gsArguments `
        -RedirectStandardOutput 'ghostscript.stdout.txt' `
        -RedirectStandardError 'ghostscript.stderr.txt' -NoNewWindow -Wait -PassThru
    if ($gs.ExitCode -ne 0) { throw 'Test-only Ghostscript conversion failed.' }
}
finally { Pop-Location }

$referencePdf = Join-Path $referenceDirectory 'wsp-documentation.pdf'
$candidatePdf = Join-Path $nativeDirectory 'wsp-documentation-dvi.pdf'
$report = Join-Path $outputPath 'visual-report.json'
$diffs = Join-Path $outputPath 'visual-diffs'
& $pythonPath (Join-Path $PSScriptRoot 'Compare-WspVisual.py') `
    $referencePdf $candidatePdf --output $report --diff-directory $diffs
if ($LASTEXITCODE -ne 0) { throw 'WSP visual equivalence comparison failed.' }

[pscustomobject]@{
    WspCommit = '9b7a9733f0566ef44f84305ea07694998fd76fa2'
    Pandoc = '3.10.1'
    Pages = 101
    ReferencePdf = $referencePdf
    NativeDvi = Join-Path $nativeDirectory 'wsp-documentation.dvi'
    VisualReport = $report
}
