# kerTeX native Windows build

This repository provides a native Windows CMake port of kerTeX using the
WPM-packaged TinyCC and WCRT toolchain. It packages Plain TeX and a focused
LaTeX runtime capable of compiling Pandoc's normal WSP LaTeX output to DVI.
The target matrix is:

| Target | Intended Windows range |
|---|---|
| x86 | Windows 2000 through Windows 11 |
| x64 | x64 editions of Windows |
| ARM64 | Windows 10 and Windows 11 on ARM |

Install the prerelease, architecture-matched `tinycc` package and WCRT 0.9.4 or
newer with WPM. WCRT 0.9.5 and newer use the `any` package architecture and
contain target-specific libraries for x86, x64, and ARM64. Then
configure and build one of the presets:

```powershell
cmake --preset x86-release
cmake --build --preset build-x86-release
cmake --install out/build/x86-release
```

Replace `x86` with `x64` or `arm64` for the other targets. `WPM_TCC_ROOT` and
`WPM_WCRT_ROOT` can select package trees outside their standard Program Files
locations.

Download the pinned upstream kerTeX bundle and all checksum-locked LaTeX
source/license archives locally with:

```powershell
cmake --build out/build/x86-release --target download-sources
```

The download is accepted only when its SHA-256 is
`EE42DEB024636963B9AB2322F3FC7EBE04710FF23B7F73B41C880F71E26A1CE5`.
Source generation currently requires a POSIX host with `make`, a C compiler,
flex, bison, and `ed`. From WSL or Linux, generate the shared tree with:

```sh
sh tools/generate-kertex-sources.sh \
  out/downloads/kertex_bundle.tar "$PWD" out/generated
```

Reconfigure a Windows preset after `out/generated` has been populated.
Assemble the LaTeX runtime before configuring CMake; once the archives have
been acquired, this step is offline:

```powershell
.\tools\Get-LatexRuntime.ps1 -Offline
```

For a local build equivalent to the CI source-generation and Windows build
stages, install WSL with `make`, a C compiler, flex, bison, and `ed`, then run:

```powershell
.\tools\Build-Native.ps1
```

The script verifies or downloads all pinned sources, generates the shared C and
runtime tree through WSL, assembles the LaTeX closure before CMake, fresh-configures
every architecture executable on the local host, builds and installs it, runs
CTest and a clean-install LaTeX smoke, verifies the native inventory, and checks
every generated PE file. An
x64 host builds x86 and x64 by default; an ARM64 host builds all three. ARM64
format generation requires an ARM64 Windows host because the build executes the
target initialization engines. Pass `-Architecture x64` to select architectures or
`-SkipGeneration` to reuse the existing `out/generated` tree.

See [Native `initex` Plain-format debugging](docs/initex-plain-format-debugging.md)
for the resolved generated-array corruption that previously prevented
`plain.fmt` creation and for the current regression checks.

## Case-colliding upstream files on Windows

The `kertex_T` submodule tracks two filename pairs that differ only by case:
`mp/lib/charlib/Ao` and `mp/lib/charlib/ao`, plus
`mp/lib/charlib/LH` and `mp/lib/charlib/lh`. A checkout on the usual
case-insensitive Windows filesystem cannot represent both members of each pair
independently. As a result, `git status` may report `kertex_T` as modified
immediately after checkout even when no source file was intentionally edited.

A case-sensitive checkout is the preferred solution. If that is not practical,
the unavoidable local differences can be hidden in the submodule index:

```powershell
git -C kertex_T update-index --skip-worktree -- `
  mp/lib/charlib/Ao mp/lib/charlib/ao `
  mp/lib/charlib/LH mp/lib/charlib/lh
```

This is a local workaround only; it does not change commits or resolve the
upstream collision. Re-enable normal change detection before investigating or
editing these files:

```powershell
git -C kertex_T update-index --no-skip-worktree -- `
  mp/lib/charlib/Ao mp/lib/charlib/ao `
  mp/lib/charlib/LH mp/lib/charlib/lh
```

## Compile a LaTeX file

After installing the package and opening a new terminal so the WPM environment
is visible, compile a LaTeX input to DVI with:

```powershell
latex document.tex
```

`latex.exe` selects `latex.fmt` automatically; an explicit `&latex` argument is
not required. The package includes LaTeX 2020-10-01 patch level 4 and the exact
170-file runtime closure captured for Pandoc 3.10.1 and WSP commit
`9b7a9733f0566ef44f84305ea07694998fd76fa2`. Runtime lookup uses relocatable
KerTeX `KXPATH` files. It does not use MiKTeX, TeX Live, Cygwin, WSL, or a POSIX
shell after installation.

The primary output is DVI. The included `dvips.exe` still does not constitute a
complete packaged PostScript/PDF conversion product; optional local validation
uses external dvips and Ghostscript to render comparison images. Native PDF
output is not provided.

Modern LaTeX and Pandoc require string/file primitives that stock evirtex does
not implement. The dedicated LaTeX executable therefore uses KerTeX's native
Prote source set (e-TeX plus those primitives), with a small command adapter
that selects `latex.fmt` by default. `evirtex.exe` remains available and
unchanged for its existing purpose; no redundant `elatex.exe` is installed.

See [native build instructions](docs/native-build.md),
[runtime environment](docs/runtime-environment.md),
[WPM package details](docs/wpm-package.md), and
[WSP validation evidence](docs/wsp-latex-validation.md).

## Compile a Plain TeX file

After installing the package and opening a new terminal so the WPM environment
is visible, compile a Plain TeX input to DVI with:

```powershell
tex document.tex
```

The native package includes `plain.fmt`, the core Plain TeX inputs, and the
font metrics needed during compilation. Each architecture generates and tests
its own `plain.fmt` with the target `initex`; format dumps are not shared across
x86, x64, and ARM64 packages. The native `dvips` executable is built, although
its complete PostScript conversion runtime is not packaged. PDF output is not
included.

The port always builds the source-native `mptotex` and `mptotr` utilities.
When the generated tree is present it builds 34 installed native executables,
including `latex.exe`,
the CWEB tools (`ctangle`, `cweave`, and `cwmerge`), METAFONT (`inimf` and
`virmf`), MetaPost (`inimp` and `virmp`), Prote (`iniprote` and `virprote`),
and e-TeX (`einitex` and `evirtex`). It also creates architecture-native
`latex.fmt`, `plain.fmt`, `plain.base`, and `plain.mem` files during the build.

The native MF and MetaPost builds use kerTeX's fixed-point arithmetic mode.
Because TinyCC does not reliably emit configured-header dependencies, rebuild
from a fresh preset after changing `cmake/kertex.h.in`.

GitHub Actions additionally downloads the pinned official source bundle,
verifies its SHA-256 digest, and runs `tools/generate-kertex-sources.sh` on an
Ubuntu host. The resulting C tree is shared by all three Windows jobs. The
generated-program slice includes WEB and the standalone WEB-derived utilities,
the TeX engines, CWEB, METAFONT, MetaPost, Prote, and e-TeX. Every architecture
job runs the focused LaTeX smoke, clean-install smoke, and exact WSP DVI build.
The x64 job additionally compares reference pdfLaTeX output with rendered DVI
on seven representative pages using checked thresholds.

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

Install WPM, then trust the kerTeX release key and add the GitHub Release as a
package repository:

```powershell
$installer = Join-Path $env:TEMP 'wpm-install.cmd'
Invoke-WebRequest -UseBasicParsing `
  https://github.com/Thewafflication/wpm/releases/latest/download/install.cmd `
  -OutFile $installer
& $installer

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
