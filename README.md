# kerTeX native Windows build

This repository is adding a native Windows CMake port of kerTeX using the
WPM-packaged TinyCC and WCRT toolchain. The target matrix is:

| Target | Intended Windows range |
|---|---|
| x86 | Windows 2000 through Windows 11 |
| x64 | x64 editions of Windows |
| ARM64 | Windows 10 and Windows 11 on ARM |

Install the `tinycc` and architecture-matched `wcrt` packages with WPM, then
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

Release targets link WCRT statically with `-nostdlib`. `tools/Verify-Pe.ps1`
checks the PE machine type, the legacy x86 subsystem baseline, and absence of
MSVCRT/UCRT imports. Passing that structural check is necessary but does not by
itself constitute a Windows 2000 runtime test.
