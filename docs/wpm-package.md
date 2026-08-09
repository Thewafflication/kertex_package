# WPM package contents and verification

Each x86, x64, or ARM64 archive contains 34 native executables, the four native
dumps (`plain.fmt`, `latex.fmt`, `plain.base`, and `plain.mem`), the core
KerTeX runtime, and the pinned LaTeX closure. `latex_init.exe` is a private
build tool and is not installed. `elatex.exe` is not included.

The LaTeX license directory contains LPPL, SIL OFL 1.1, the GUST Font License,
AMSFonts, Latin Modern, Computer Modern, and EC upstream notices/manifests, the
source locks, runtime manifest, and project copyright inventory. KerTeX's
top-level `COPYRIGHTS` remains packaged separately.

Build an archive only after installing the selected architecture:

```powershell
.\tools\Build-WpmPackage.ps1 `
  -Architecture x64 -Version 0.99.27-ci.1
```

Before staging, the script runs native-install verification. It then reopens
the ZIP and requires `latex.exe`, `latex.fmt`, matching format provenance,
every file named by `runtime-manifest.txt`, both `KXPATH` files, and all license
notices. PE/import checks remain a separate `Verify-Pe.ps1` gate in CI.

The installer sets `KERTEX_HOME`, `KERTEX_BINDIR`, and `KERTEX_LIBDIR`, and
adds `%KERTEX_HOME%\bin` to the machine `Path`. A new terminal can immediately
run `latex document.tex`; no post-install filename database or format command
is required.

The product output is DVI. External MiKTeX, dvips, Ghostscript, PDFium, and
Python tools used by optional local visual validation are not included in the
WPM archive.
