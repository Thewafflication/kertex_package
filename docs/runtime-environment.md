# Runtime paths and environment

The WPM installer writes three machine environment variables and adds the bin
directory to `Path`:

| Variable | Installed value | Purpose |
|---|---|---|
| `KERTEX_HOME` | `%ProgramFiles%\KerTeX\<version>` | Relocatable package root |
| `KERTEX_BINDIR` | `%KERTEX_HOME%\bin` | Executables and `bin\lib\latex.fmt` |
| `KERTEX_LIBDIR` | `%KERTEX_HOME%\share\kertex` | TeX inputs, pools, fonts, and notices |

Open a new terminal after installation so the machine environment is visible.
No `KERTEXDUMP`, `KERTEXFONTS`, or `KERTEXINPUTS` override is required.
Engines derive their normal roots from `KERTEX_BINDIR` and `KERTEX_LIBDIR`.

KerTeX does not recursively search a TeX Live-style tree. The package places
the flat LaTeX closure in `share\kertex\prote\latex`, its metrics in
`share\kertex\fonts\latex`, and installs these path specifications:

```text
share/kertex/prote/KXPATH: latex
share/kertex/fonts/KXPATH: latex;tfm
```

The second entry retains the existing core `fonts\tfm` search path. All path
specifications are relative to `KERTEX_LIBDIR`, so moving the package and
updating the three root variables preserves lookup behavior.

The supported command is:

```powershell
latex document.tex
```

It writes DVI. MiKTeX/TeX Live variables and filename databases are neither
consulted nor required.
