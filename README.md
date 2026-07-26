# kerTeX native Windows build

This repository is adding a native Windows CMake port of kerTeX using the
WPM-packaged TinyCC and WCRT toolchain. The target matrix is:

| Target | Intended Windows range |
|---|---|
| x86 | Windows 2000 through Windows 11 |
| x64 | x64 editions of Windows |
| ARM64 | Windows 10 and Windows 11 on ARM |

Install the prerelease `tinycc` package and the published, architecture-matched
WCRT 0.9.4 or newer with WPM, then
configure and build one of the presets:

```powershell
cmake --preset x86-release
cmake --build --preset build-x86-release
cmake --install out/build/x86-release
```

Replace `x86` with `x64` or `arm64` for the other targets. `WPM_TCC_ROOT` and
`WPM_WCRT_ROOT` can select package trees outside their standard Program Files
locations.

Download the pinned upstream bundle locally with:

```powershell
cmake --build out/build/x86-release --target download-sources
```

The download is accepted only when its SHA-256 is
`B87408CC963BE3B013BE588935861771C7ACCA011BECF2888FA9629C1B97B3B4`.
Source generation currently requires a POSIX host with `make`, a C compiler,
flex, bison, and `ed`. From WSL or Linux, generate the shared tree with:

```sh
sh tools/generate-kertex-sources.sh \
  out/downloads/kertex_bundle.tar "$PWD" out/generated
```

Reconfigure a Windows preset after `out/generated` has been populated.

The port always builds the source-native `mptotex` and `mptotr` utilities.
GitHub Actions additionally downloads the pinned official source bundle,
verifies its SHA-256 digest, and runs `tools/generate-kertex-sources.sh` on an
Ubuntu host. The resulting C tree is shared by all three Windows jobs. The
first generated-program slice includes WEB and the standalone WEB-derived TeX,
METAFONT, font, DVI, and MetaPost utilities. The large TeX, METAFONT, MetaPost,
e-TeX, and Prote engines will be connected after this slice establishes the
cross-runtime compatibility fixes they share.

Release targets link WCRT statically with `-nostdlib` and use WCRT's packaged
console startup object as the PE entry point. `tools/Verify-Pe.ps1`
checks the PE machine type, the legacy x86 subsystem baseline, and absence of
MSVCRT/UCRT imports. Passing that structural check is necessary but does not by
itself constitute a Windows 2000 runtime test.

Each Windows CI job also creates an architecture-specific WPM package from the
CMake install tree. Tagged builds use the semantic version from the tag; other
builds combine the upstream version from `kertex_T/CID` with a unique `ci`
prerelease and source revision. Installation places kerTeX
under Program Files, sets `KERTEX_HOME`, `KERTEX_BINDIR`, and `KERTEX_LIBDIR`,
and adds the package's `bin` directory to the machine `Path`.

Published tagged builds form a WPM repository at the release's
`releases/latest/download` URL. Each release contains signed x86, x64, and
ARM64 packages, `index.json`, the WPM release public key, and SHA-256 checksums.

## Install with WPM

Install WPM first, then trust the kerTeX release key and add the release as a
package repository:

```powershell
Invoke-WebRequest -UseBasicParsing `
  https://github.com/Thewafflication/kertex_package/releases/latest/download/wpm-release.public `
  -OutFile wpm-release.public
wpm trust add wpm-release.public
wpm repo add https://github.com/Thewafflication/kertex_package/releases/latest/download
wpm update
wpm install kertex
```

WPM selects the native architecture by default. To choose one explicitly, use
`wpm install kertex --arch x86`, `--arch x64`, or `--arch arm64`.

That same resolved version is embedded in every executable's Windows
`VERSIONINFO` resource and used by the WPM metadata and filename. The numeric
Windows version maps to `major, minor, patch, build`; tagged releases use build
zero and CI builds use the bounded Actions run number. The upstream kerTeX
version from `kertex_T/CID` is retained separately as `SourceVersion`.
