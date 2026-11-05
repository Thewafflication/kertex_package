# Project Work Tracker

## Current Status
- **Branch**: `master` (up to date with `origin/master`)
- **Last commit**: `bcf686a` - feat: add project work and agent tasks trackers per WSP-PROC-0012 adoption
- **Working directory**: Clean with untracked `tests/__pycache__` directory

## Outstanding Work / Prerequisites
### Required before full build:
1. **Download kerTeX source bundle** - Run `cmake --build out/build/x86-release --target download-sources` 
   - Verified SHA-256 must match: `EE42DEB024636963B9AB2322F3FC7EBE04710FF23B7F73B41C880F71E26A1CE5`
   - *Note: Download requires POSIX host with make, C compiler, flex, bison, and ed (via WSL or Linux)*
   
2. **Acquire LaTeX Runtime** - Run `.\tools\Get-LatexRuntime.ps1 -Offline` 
   - Assembles LaTeX closure before CMake configuration

3. **WSL/Linux environment** (for source generation):
   - Install: `make`, C compiler, flex, bison, `ed`
   - Run: `sh tools/generate-kertex-sources.sh out/downloads/kertex_bundle.tar "$PWD" out/generated`

### Architecture-specific notes:
- **x86**: Windows 2000 through Windows 11
- **x64**: x64 editions of Windows  
- **ARM64**: Windows 10 and Windows 11 on ARM (requires ARM64 Windows host for format generation)

## Branch/Worktree Information
- **Current branch**: `master`
- **No active worktrees**
- **Submodules**: 
  - `kertex_T` - case-colliding filenames (Ao/ao, LH/lh) on case-insensitive Windows
  - `tools/wsp` - version 1.0.0

## Acceptance Commands
Build and validate one of the presets:

```powershell
cmake --preset x86-release
cmake --build --preset build-x86-release
cmake --install out/build/x86-release
```

Replace `x86` with `x64` or `arm64` for other targets.

### Validation tests:
```powershell
python -m pytest tests/test_version.py tests/test_cmake.py
```

### Download sources verification:
- SHA-256 must be: `EE42DEB024636963B9AB2322F3FC7EBE04710FF23B7F73B41C880F71E26A1CE5`

### LaTeX runtime assembly:
```powershell
.\tools\Get-LatexRuntime.ps1 -Offline
```

## Publication Target
- **Upstream repository**: The kerTeX Windows build project
- **CI/CD**: GitHub Actions (configured for Node testing, CMake presets)
- **Release**: Semantic version `0.1.0` per CMakeLists.txt `KERTEX_PACKAGE_VERSION`
- **Assets**: Built executables installed via `cmake --install`

## Known Issues / last failure experiment
- **commit1ed30bc**: Added HTML README comment for commit validation - *not a functional milestone* (per monitoring notes)
- **commit882eb2bd**: Pytest installed, all tests pass - but has zero file changes (per monitoring audit 2026-10-31)
- **cdd3aca81**: Moved module-level version assertions into explicit `pytest test_version` function - test structure improvement only
- **bcf686a**: Added PROJECT-WORK.md and AGENT-TASKS.md trackers per WSP-PROC-0012 adoption - planning adoption, not a successful native build

## Monitoring audit status
- **2026-10-31**: commit882eb2bd4ae607689fee05e7de3ff6791446ccff matches live origin/master but has zero file changes - does not satisfy useful milestone requirement
- **2026-11-01**: cdd3aca8140233712478f7522544e3477aabdaf6 moved test assertions into pytest function - collection structure improvement only
- **2026-11-05**: bcf686a5aa623788731f7dd20672cc14e2a6dc92 published both work trackers - treat as planning adoption, not a successful native build
- **Do not repeat**: empty commits, README markers, or comment-only changes to satisfy commit/push ceremony

## Next Concrete Experiment
Identify and reproduce a concrete build/packaging defect from actual requirements, then implement bounded fix/feature. Do not manufacture placeholder commits.