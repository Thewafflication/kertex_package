[CmdletBinding()]
param(
    [ValidateSet('x86', 'x64', 'arm64')]
    [string[]] $Architecture,

    [switch] $SkipGeneration
)

$ErrorActionPreference = 'Stop'
$hostArchitecture = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
if (-not $Architecture) {
    $Architecture = switch ($hostArchitecture) {
        'Arm64' { @('x86', 'x64', 'arm64') }
        'X64' { @('x86', 'x64') }
        'X86' { @('x86') }
        default { throw "Unsupported Windows host architecture: $hostArchitecture" }
    }
}
if ($Architecture -contains 'arm64' -and $hostArchitecture -ne 'Arm64') {
    throw 'ARM64 builds execute target initex to create plain.fmt and require an ARM64 Windows host'
}
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$bundle = Join-Path $repositoryRoot 'out\downloads\kertex_bundle.tar'
$generated = Join-Path $repositoryRoot 'out\generated'

function Get-RequiredCommandPath {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string[]] $Fallback
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    foreach ($candidate in $Fallback) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    throw "$Name was not found"
}

function ConvertTo-WslPath {
    param([Parameter(Mandatory)] [string] $Path)

    $resolved = [IO.Path]::GetFullPath($Path)
    # wsl.exe treats backslashes in forwarded arguments as shell escapes.
    $forwardedPath = $resolved.Replace('\', '/')
    $wslPath = & wsl.exe wslpath -a -u $forwardedPath
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($wslPath)) {
        throw "WSL could not translate path: $resolved"
    }
    return $wslPath.Trim()
}

if (-not $SkipGeneration) {
    & (Join-Path $PSScriptRoot 'Get-KertexBundle.ps1') -Destination $bundle

    $missing = & wsl.exe sh -lc `
        'for tool in make cc flex bison ed; do command -v "$tool" >/dev/null || printf "%s\n" "$tool"; done'
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect WSL generator prerequisites' }
    $missing = @($missing | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($missing) {
        throw "WSL is missing generator prerequisites: $($missing -join ', ')"
    }

    $generator = ConvertTo-WslPath (Join-Path $PSScriptRoot 'generate-kertex-sources.sh')
    $wslBundle = ConvertTo-WslPath $bundle
    $wslRepository = ConvertTo-WslPath $repositoryRoot
    $wslGenerated = ConvertTo-WslPath $generated
    # Keep the disposable upstream checkout on WSL's case-sensitive filesystem.
    # kerTeX contains files whose names differ only by case, so generator scratch
    # trees on the usual Windows filesystem cannot be cleaned or overlaid safely.
    & wsl.exe env 'KERTEX_GENERATOR_WORK=/tmp/kertex-package-generator' `
        sh $generator $wslBundle $wslRepository $wslGenerated
    if ($LASTEXITCODE -ne 0) { throw 'WSL kerTeX source generation failed' }
}

$cmake = Get-RequiredCommandPath -Name 'cmake.exe' -Fallback @(
    'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
)
$ninja = Get-RequiredCommandPath -Name 'ninja.exe' -Fallback @(
    'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe'
)
$ctest = Join-Path (Split-Path -Parent $cmake) 'ctest.exe'

foreach ($targetArchitecture in $Architecture) {
    & $cmake --fresh --preset "$targetArchitecture-release" "-DCMAKE_MAKE_PROGRAM=$ninja"
    if ($LASTEXITCODE -ne 0) { throw "CMake configure failed for $targetArchitecture" }
    & $cmake --build --preset "build-$targetArchitecture-release"
    if ($LASTEXITCODE -ne 0) { throw "CMake build failed for $targetArchitecture" }
    & $cmake --install "out/build/$targetArchitecture-release"
    if ($LASTEXITCODE -ne 0) { throw "CMake install failed for $targetArchitecture" }
    & $ctest --test-dir "out/build/$targetArchitecture-release" --output-on-failure
    if ($LASTEXITCODE -ne 0) { throw "CTest failed for $targetArchitecture" }

    $installRoot = "out/install/$targetArchitecture-release"
    & (Join-Path $PSScriptRoot 'Verify-NativeInstall.ps1') -InstallRoot $installRoot

    Get-ChildItem "$installRoot/bin" -Filter '*.exe' |
        ForEach-Object {
            & (Join-Path $PSScriptRoot 'Verify-Pe.ps1') `
                -Path $_.FullName -Architecture $targetArchitecture
            if ($LASTEXITCODE -ne 0) {
                throw "PE verification failed for $($_.FullName)"
            }
        }
}
