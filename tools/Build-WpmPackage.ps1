[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('x86', 'x64', 'arm64')]
    [string]$Architecture,
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$InstallRoot = 'out/install',
    [string]$PackageRoot = 'out/packages',
    [string]$Wpm = 'wpm.exe',
    [string]$SigningKey
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$packageVersion = $Version -replace '^v', ''
if ($packageVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$') {
    throw "KerTeX package version is not semantic: $Version"
}

$payload = Join-Path $repositoryRoot "$InstallRoot/$Architecture-release"
$binDirectory = Join-Path $payload 'bin'
$shareDirectory = Join-Path $payload 'share/kertex'
if (-not (Test-Path -LiteralPath $binDirectory -PathType Container) -or
    -not (Get-ChildItem -LiteralPath $binDirectory -Filter '*.exe' -File)) {
    throw "The KerTeX install tree has no executables: $binDirectory"
}
if (-not (Test-Path -LiteralPath $shareDirectory -PathType Container)) {
    throw "The KerTeX install tree has no runtime data: $shareDirectory"
}

$staging = Join-Path $repositoryRoot "out/wpm-staging/$Architecture"
$packageOutput = Join-Path $repositoryRoot $PackageRoot
if (Test-Path -LiteralPath $staging) {
    Remove-Item -LiteralPath $staging -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $staging, (Join-Path $staging '.wpm'), $packageOutput | Out-Null
Copy-Item -Path (Join-Path $payload '*') -Destination $staging -Recurse
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'README.md') -Destination $staging
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'kertex_T/COPYRIGHTS') -Destination $staging

$gitHash = (& git -C $repositoryRoot rev-parse --short=8 HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not determine the KerTeX package source revision.' }
$metadata = @(
    'name=kertex'
    "version=$packageVersion"
    "arch=$Architecture"
    'debug=false'
    'description=Native KerTeX typesetting tools for Windows'
    'maintainer=Jordan Waughtal'
    'homepage=https://github.com/Thewafflication/kertex_package'
    'repository=https://github.com/Thewafflication/kertex_package'
    'license=LicenseRef-KerTeX'
    "source-version=$packageVersion"
    "source-revision=$gitHash"
)
Set-Content -LiteralPath (Join-Path $staging '.wpm/package.txt') -Value $metadata -Encoding ascii

$installDirectory = "%ProgramFiles%\KerTeX\$packageVersion"
$installScript = @(
    '@echo off'
    'setlocal EnableDelayedExpansion'
    ('set "KERTEX_DEST={0}"' -f $installDirectory)
    'set "KERTEX_ENV=HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"'
    'if not exist "%KERTEX_DEST%" mkdir "%KERTEX_DEST%" || exit /b 1'
    'xcopy "%~dp0..\*" "%KERTEX_DEST%\" /E /I /Q /Y >nul || exit /b 1'
    'if exist "%KERTEX_DEST%\.wpm" rmdir /S /Q "%KERTEX_DEST%\.wpm"'
    'reg add "%KERTEX_ENV%" /v KERTEX_HOME /t REG_EXPAND_SZ /d "%KERTEX_DEST%" /f >nul || exit /b 1'
    'reg add "%KERTEX_ENV%" /v KERTEX_BINDIR /t REG_EXPAND_SZ /d "%KERTEX_DEST%\bin" /f >nul || exit /b 1'
    'reg add "%KERTEX_ENV%" /v KERTEX_LIBDIR /t REG_EXPAND_SZ /d "%KERTEX_DEST%\share\kertex" /f >nul || exit /b 1'
    'set "KERTEX_PATH="'
    'for /f "tokens=1,2,*" %%A in (''reg query "%KERTEX_ENV%" /v Path 2^>nul ^| find /I "Path"'') do set "KERTEX_PATH=%%C"'
    'echo;!KERTEX_PATH!;| findstr /I /L /C:";%%KERTEX_HOME%%\bin;" >nul'
    'if errorlevel 1 set "KERTEX_PATH=!KERTEX_PATH!;%%KERTEX_HOME%%\bin"'
    'reg add "%KERTEX_ENV%" /v Path /t REG_EXPAND_SZ /d "!KERTEX_PATH!" /f >nul || exit /b 1'
    'exit /b 0'
)
$removeScript = @(
    '@echo off'
    'setlocal EnableDelayedExpansion'
    ('set "KERTEX_DEST={0}"' -f $installDirectory)
    'set "KERTEX_ENV=HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"'
    'if exist "%KERTEX_DEST%" rmdir /S /Q "%KERTEX_DEST%" || exit /b 1'
    'set "KERTEX_CURRENT="'
    'for /f "tokens=2,*" %%A in (''reg query "%KERTEX_ENV%" /v KERTEX_HOME 2^>nul'') do set "KERTEX_CURRENT=%%B"'
    'if /I not "%KERTEX_CURRENT%"=="%KERTEX_DEST%" exit /b 0'
    'set "KERTEX_PATH="'
    'for /f "tokens=1,2,*" %%A in (''reg query "%KERTEX_ENV%" /v Path 2^>nul ^| find /I "Path"'') do set "KERTEX_PATH=%%C"'
    'set "KERTEX_PATH=!KERTEX_PATH:;%%KERTEX_HOME%%\bin=!"'
    'set "KERTEX_PATH=!KERTEX_PATH:%%KERTEX_HOME%%\bin;=!"'
    'set "KERTEX_PATH=!KERTEX_PATH:%%KERTEX_HOME%%\bin=!"'
    'reg add "%KERTEX_ENV%" /v Path /t REG_EXPAND_SZ /d "!KERTEX_PATH!" /f >nul'
    'reg delete "%KERTEX_ENV%" /v KERTEX_HOME /f >nul 2>&1'
    'reg delete "%KERTEX_ENV%" /v KERTEX_BINDIR /f >nul 2>&1'
    'reg delete "%KERTEX_ENV%" /v KERTEX_LIBDIR /f >nul 2>&1'
    'exit /b 0'
)
Set-Content -LiteralPath (Join-Path $staging '.wpm/install.cmd') -Value $installScript -Encoding ascii
Set-Content -LiteralPath (Join-Path $staging '.wpm/remove.cmd') -Value $removeScript -Encoding ascii

$arguments = @('build', $staging, $packageOutput)
if (-not [string]::IsNullOrWhiteSpace($SigningKey)) {
    $arguments += @('--sign', (Resolve-Path -LiteralPath $SigningKey).Path)
}
& $Wpm @arguments
if ($LASTEXITCODE -ne 0) { throw 'WPM failed to create the KerTeX package.' }

$package = @(Get-ChildItem -LiteralPath $packageOutput -Filter "kertex-$Architecture-$packageVersion.zip" -File)
if ($package.Count -ne 1) {
    throw "Expected one KerTeX WPM package for $Architecture $packageVersion."
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($package[0].FullName)
try {
    $entries = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    foreach ($required in @('.wpm/package.txt', '.wpm/install.cmd', '.wpm/remove.cmd')) {
        if ($required -notin $entries) { throw "KerTeX package is missing $required" }
    }
    if (-not ($entries | Where-Object { $_ -match '^bin/.+\.exe$' })) {
        throw 'KerTeX package contains no Windows executables.'
    }
    if (-not ($entries | Where-Object { $_ -like 'share/kertex/*' })) {
        throw 'KerTeX package contains no runtime data.'
    }
} finally {
    $archive.Dispose()
}
$package[0].FullName
