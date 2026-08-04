# Native `initex` Plain-format failure

## Status

Resolved in the source generator. A clean WSL generation followed by the x86
native build now creates `plain.fmt` and passes `plain-tex-smoke`.

## Symptom

The native Windows `initex.exe` read `plain.tex` and `hyphen.tex` without a TeX
input error, but rejected the subsequent format dump:

```text
! You can't dump inside a group.
<*> \input plain \dump
```

A standalone `\dump` succeeded. Loading `plain.tex` first made `storefmtfile()`
observe a nonzero `saveptr`, even though `\endgroup` reported that no TeX group
was open. This distinguished corrupted save-stack state from an unmatched group
in `plain.tex`.

## Root cause

`pp2rc` emits Pascal arrays with nonzero logical lower bounds as pointers before
small C backing arrays:

```c
#define xeqlevel (zzzad -422593)
zzzad[844];
#define hash (zzzae -514)
zzzae[419697];
```

The generator already attempted to replace these undefined pointer expressions
with zero-based arrays large enough to preserve the original logical indices.
The macro replacements succeeded, but the array-size replacements silently did
not. Generated declarations had whitespace after the semicolon, while the
`sed` expressions required the semicolon to be the final character.

The resulting header therefore contained this invalid combination:

```c
#define xeqlevel zzzad
zzzad[844];
#define hash zzzae
zzzae[419697];
```

TeX indexes `xeqlevel` around 422593. Those accesses ran far beyond the
844-element allocation and overwrote later globals, including `savestack` and
`saveptr`. The dump error was a secondary symptom of that overwrite.

## Fix and guard

`tools/fix-generated-array-layout.sh`, invoked by the source generator, now
uses whitespace-tolerant expressions and produces:

```c
#define xeqlevel zzzad
zzzad[423437];
#define hash zzzae
zzzae[420211];
```

Generation now fails immediately unless both macro rewrites and both enlarged
declarations are present in the `initex` and `virtex` headers. This converts the
previous silent partial rewrite into a generator error.

## Reproduction and verification

Run the CI-equivalent local workflow:

```powershell
.\tools\Build-Native.ps1 -Architecture x86
```

The workflow must complete all of these stages:

1. Generate the shared C and runtime tree through WSL.
2. Build native `initex.exe` and create `runtime/lib/plain.fmt`.
3. Build the complete currently supported executable set.
4. Pass the Plain TeX and additional-engine CTests.
5. Verify the 33-executable and three-format install inventory.
6. Pass PE architecture and external-CRT verification.

If the generator fails before CMake, inspect both generated headers and confirm
the four rewritten lines above. If `initex` again reports a nonzero save stack,
check generated array bounds before investigating TeX grouping or WCRT I/O.
