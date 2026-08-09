# Changelog

## Unreleased

- Updated the pinned upstream kerTeX source and bundle to 0.99.27.00, with
  retrying checksum verification and durable pre-generation CI diagnostics.
- Added native `latex.exe` and independently generated x86, x64, and ARM64
  `latex.fmt` targets while preserving Plain TeX and the existing engines.
- Added a checksum-pinned TeX Live 2020 final LaTeX runtime closure, KerTeX
  `KXPATH` layout, complete LPPL/OFL/GUST notices, and architecture provenance.
- Added focused LaTeX, clean-install, exact WSP DVI, `dvitype`, and quantified
  PDF/DVI visual-equivalence tests.
- Extended WPM archive verification and the native Windows CI architecture
  matrix for the LaTeX capability.
