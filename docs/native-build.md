# Native build and offline rebuild

## Prerequisites

Install the architecture-matched WPM TinyCC package, WCRT 0.9.4 or newer,
CMake, Ninja, PowerShell, and WSL or another POSIX generator host with `make`,
a C compiler, flex, bison, and `ed`. Source generation is host-side only; none
of these POSIX tools are runtime dependencies.

## Acquire sources

After configuring any preset, acquire the official kerTeX bundle, 50 pinned
TeX Live 2020 final runtime archives, and four matching license-documentation
archives:

```powershell
cmake --build out/build/x64-release --target download-sources
```

The accepted archive names, revisions, versions, licenses, and SHA-256 hashes
are in `third_party/latex/sources.lock` and
`third_party/latex/license-sources.lock`. Acquisition is the only networked
part of the native build.

## Generate and assemble

```powershell
wsl.exe sh tools/generate-kertex-sources.sh `
  out/downloads/kertex_bundle.tar "$PWD" out/generated
.\tools\Get-LatexRuntime.ps1 -Offline
```

The second command verifies every cached archive again, extracts into a clean
tree, applies deterministic KerTeX compatibility patches, copies only the
files in `runtime-manifest.txt`, and validates the resulting exact inventory.
CMake, CTest, install verification, and WPM verification perform no downloads.

## Build and test

```powershell
cmake --fresh --preset x64-release
cmake --build --preset build-x64-release
cmake --install out/build/x64-release
ctest --test-dir out/build/x64-release --output-on-failure
.\tools\Verify-NativeInstall.ps1 `
  -InstallRoot out/install/x64-release -Architecture x64
.\tools\Test-InstalledLatex.ps1 `
  -InstallRoot out/install/x64-release -Architecture x64
```

Replace `x64` with `x86` or `arm64`. Each build executes that target's private
`latex_init.exe` and creates `runtime/lib/latex.fmt`; it never copies a format
from another build. `latex.fmt.provenance` records the target architecture,
format SHA-256, kernel version, and fixed format date. Verification rejects an
architecture mismatch, hash mismatch, missing manifest file, or generator
absolute path.

Target initialization requires a host capable of running the target PE. An
x64 Windows host can test x86 and x64. ARM64 format generation and tests run on
an ARM64 Windows host (`windows-11-arm` in CI).

`tools/Build-Native.ps1` performs this workflow for every architecture the
current host can execute. Use `-SkipGeneration` to reuse `out/generated`; the
pinned LaTeX assembly step still runs before CMake.
