[CmdletBinding()]
param(
    [string] $WspRoot = 'tools/wsp',
    [string] $OutputPath = 'out/wsp-integration/wsp-documentation.tex',
    [string] $Pandoc = 'out/tools/pandoc-3.10.1/pandoc.exe',
    [string] $Version = '0.0.0-test',
    [string] $BuildDate = '2026-01-01'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Resolve-ProjectPath([string] $Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $repositoryRoot $Path))
}
$wspFullPath = Resolve-ProjectPath $WspRoot
$manifestPath = Join-Path $wspFullPath 'documentation/documentation-manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$pandocPath = Resolve-ProjectPath $Pandoc
$outputFullPath = Resolve-ProjectPath $OutputPath
$outputDirectory = Split-Path -Parent $outputFullPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$sourceRevision = (& git -c "safe.directory=$($wspFullPath.Replace('\', '/'))" `
    -C $wspFullPath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not resolve the pinned WSP revision.' }
$pandocVersion = (& $pandocPath --version | Select-Object -First 1).Trim()
$shortRevision = $sourceRevision.Substring(0, 12)
$emDash = [char]0x2014
$titleDate = "$BuildDate $emDash Version $Version $emDash Commit $shortRevision"
$temporaryDirectory = Join-Path $outputDirectory 'generated-inputs'
New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
$buildInformation = Join-Path $temporaryDirectory 'build-information.md'
$metadataHeader = Join-Path $temporaryDirectory 'metadata.tex'

@(
    '# Build Information'
    ''
    '| Attribute | Value |'
    '| --- | --- |'
    "| Project | $($manifest.title) |"
    "| Version | $Version |"
    "| Source revision | $sourceRevision |"
    "| Build date | $BuildDate |"
    "| Pandoc | $pandocVersion |"
    '| PDF engine | MiKTeX-pdfTeX 4.23 (MiKTeX 25.12) |'
    '| Manifest | documentation/documentation-manifest.json |'
) | Set-Content -LiteralPath $buildInformation -Encoding utf8

$metadataLines = @(
    '\AtBeginDocument{\hypersetup{'
    '  pdfinfo={'
    "    WSPVersion={$Version},"
    "    WSPSourceRevision={$sourceRevision},"
    "    WSPRepositoryURL={$($manifest.repositoryUrl)}"
    '  }'
    '}}'
)
[IO.File]::WriteAllLines($metadataHeader, $metadataLines, [Text.UTF8Encoding]::new($false))

$arguments = [Collections.Generic.List[string]]::new()
foreach ($argument in @(
        '--from=gfm+smart', '--to=latex', '--standalone', '--file-scope',
        '--toc', '--toc-depth=3', '--number-sections',
        '--top-level-division=chapter', "--output=$outputFullPath",
        "--resource-path=$wspFullPath",
        "--include-in-header=$(Join-Path $wspFullPath 'documentation/preamble.tex')",
        "--include-in-header=$metadataHeader",
        "--lua-filter=$(Join-Path $wspFullPath 'documentation/internal-links.lua')",
        '--variable=documentclass:report', '--variable=classoption:openany',
        '--variable=papersize:letter', '--variable=geometry:margin=0.85in',
        '--variable=fontsize:10pt', "--metadata=title:$($manifest.title)",
        "--metadata=author:$($manifest.author)",
        "--metadata=subject:$($manifest.subject)",
        "--metadata=keywords:$(@($manifest.keywords) -join ', ')",
        "--metadata=lang:$($manifest.language)",
        "--metadata=subtitle:$($manifest.subtitle)",
        "--variable=author:\href{$($manifest.repositoryUrl)}{\nolinkurl{$($manifest.repositoryUrl)}}",
        "--metadata=date:$titleDate", "--metadata=version:$Version",
        "--metadata=source-revision:$sourceRevision",
        "--metadata=repository-url:$($manifest.repositoryUrl)",
        "--metadata=pandoc-version:$pandocVersion",
        '--metadata=pdf-engine-version:MiKTeX-pdfTeX 4.23 (MiKTeX 25.12)'
    )) {
    $arguments.Add($argument)
}
foreach ($file in $manifest.files) {
    $arguments.Add((Join-Path $wspFullPath ([string] $file)))
}
$arguments.Add($buildInformation)

$previousManifest = $env:WSP_DOCUMENT_MANIFEST
$env:WSP_DOCUMENT_MANIFEST = $manifestPath
try {
    & $pandocPath @arguments
    if ($LASTEXITCODE -ne 0) { throw "Pandoc failed with exit code $LASTEXITCODE." }
}
finally {
    $env:WSP_DOCUMENT_MANIFEST = $previousManifest
}
if (-not (Test-Path -LiteralPath $outputFullPath -PathType Leaf) -or
    (Get-Item -LiteralPath $outputFullPath).Length -eq 0) {
    throw "Pandoc did not create a non-empty LaTeX file: $outputFullPath"
}

[pscustomobject]@{
    Output = $outputFullPath
    WspRevision = $sourceRevision
    PandocVersion = $pandocVersion
    BuildDate = $BuildDate
}
