# Packaged LaTeX runtime copyright and license inventory

The Windows package contains a deliberately minimal runtime assembled from
the TeX Live 2020 final historic snapshot. `sources.lock` records the exact
TeX Live revision, upstream version, declared license, and SHA-256 digest for
every imported runtime archive. `runtime-manifest.txt` records every file
copied into the product.

The LaTeX kernel and the packages marked `LPPL`, `LPPL-1.2`, `LPPL-1.3`, or
`LPPL-1.3c` in `sources.lock` remain copyright their respective authors and
maintainers and are distributed under the LaTeX Project Public License. The
packaged `lppl.tex` is the complete license text from the pinned LaTeX archive.

The AMSFonts metrics are copyright the American Mathematical Society and are
distributed under the SIL Open Font License 1.1. The complete `OFL.txt` and
the upstream AMSFonts `README` are copied from the matching pinned TeX Live
documentation archive.

The Latin Modern metrics and support files are copyright GUST and the Latin
Modern authors named in `README-Latin-Modern.TXT` and
`MANIFEST-Latin-Modern.TXT`. They are distributed under the GUST Font License
1.0; the complete `GUST-FONT-LICENSE.TXT` is packaged.

Computer Modern material is distributed under Donald E. Knuth's TeX/font
terms. The `cm` archive supplies metrics only to this closure; its matching
upstream `README-Computer-Modern.txt` and KerTeX's separately packaged
`COPYRIGHTS` inventory identify the source and applicable terms.

European Computer Modern (`ec`) metrics are copyright Norbert Schwarz and
Jorg Knappen. Their complete `COPYRIGHT-EC-Fonts.txt` notice and upstream file
inventory are copied from the matching pinned documentation archive.

The runtime files are unmodified except for the deterministic compatibility
patches documented in `tools/Get-LatexRuntime.ps1`. Those patches identify the
KerTeX Prote engine, avoid quoted `openin` filenames unsupported by this
engine, select its available primitive set, restrict format-time hyphenation
loading to English, and give the dedicated pool/dump their installed names.

This inventory supplements, and does not replace, the notices embedded in the
individual source files. KerTeX's own licensing and third-party inventory are
provided separately in the package's top-level `COPYRIGHTS` file.
