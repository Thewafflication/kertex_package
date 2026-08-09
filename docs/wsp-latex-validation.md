# WSP LaTeX/DVI validation

The controlled fixture is WSP commit
`9b7a9733f0566ef44f84305ea07694998fd76fa2` with Pandoc 3.10.1, version
`0.0.0-test`, build date 2026-01-01, and UTC/fixed source-date inputs. The
values are checked in at `third_party/wsp-fixture.lock`.

`Generate-WspLatex.ps1` consumes the WSP documentation manifest, its ordered
Markdown files, normal Pandoc LaTeX template, preamble, and internal-links Lua
filter. The same generated `.tex` is compiled four times by reference
MiKTeX-pdfTeX 4.27 (MiKTeX 26.5) and four times by packaged native
`latex.exe`. The DVI is validated by packaged `dvitype`, rendered with
test-only dvips and Ghostscript, and compared with `Compare-WspVisual.py`.

The pinned fixture produces 101 PDF pages and 101 DVI pages. Local x64 and x86
native runs both produced a 583,852-byte DVI. The embedded PDF font inventories
are identical: Latin Modern Roman/Mono variants and MSAM10.

Representative pages are title 1, early TOC 2, last TOC 9, chapter opening 10,
table-heavy 11, colored-link 19, and code-heavy 96. At 144 dpi, the recorded
local x64 comparison produced:

| Metric | Observed worst case | Enforced limit |
|---|---:|---:|
| Mean RGB raster difference | 0.021378 | 0.023 |
| Blurred mean difference | 0.014251 | 0.016 |
| Pixels differing by more than 32/255 | 0.049152 | 0.060 |
| Normalized extracted-text similarity | 0.999021 | at least 0.989 |
| Ink bounding-box displacement | 3 px | 3 px |
| Colored-pixel-count delta | 0.008149 | 0.030 |

These bounds admit pdfTeX/dvips antialiasing differences but reject displaced
text, changed wrapping/pagination, missing colors, materially changed tables,
or font substitution. Enhanced difference PNGs and the JSON report are kept as
the x64 CI artifact.

Run the native fixture alone with:

```powershell
.\tools\Generate-WspLatex.ps1
.\tools\Test-WspNativeLatex.ps1
```

Run the full comparison by supplying test-only tool paths:

```powershell
.\tools\Test-WspLatexIntegration.ps1 `
  -PdfLatex C:\path\pdflatex.exe `
  -Dvips C:\path\dvips.exe `
  -Ghostscript C:\path\gswin64c.exe `
  -Python C:\path\python.exe
```

CI runs the native WSP compilation on x86, x64, and ARM64. The visual renderer
gate runs once on x64 because the target-native DVI content is separately
validated in every architecture job.
