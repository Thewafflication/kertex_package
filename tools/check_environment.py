#!/usr/bin/env python3
"""Utility to verify that required build tools and environment variables are present.

This script is useful for quick sanity checks before attempting a full CMake
build.  It verifies:

* The Windows PowerShell executable (`pwsh` or `powershell`),
* TinyCC (`tcc`) is available on PATH, and its version is printed.
* The WPM packages WCRT and TinyCC root directories are accessible via the
  ``WPM_TCC_ROOT`` and ``WPM_WCRT_ROOT`` environment variables.
* The ``WCRT`` headers and console startup object exist.

The script exits with a non‑zero code if any of these checks fail.
"""

import os
import shutil
import subprocess
import sys


def check_executable(name, args="--version"):
    path = shutil.which(name)
    if not path:
        print(f"❌ {name} not found on PATH", file=sys.stderr)
        return False
    try:
        result = subprocess.run([path, args], capture_output=True, text=True, timeout=5)
        if result.returncode != 0:
            print(f"❌ {name} returned error code {result.returncode}", file=sys.stderr)
            return False
        print(f"✅ {name}: {result.stdout.splitlines()[0]}")
    except Exception as e:
        print(f"❌ Error running {name}: {e}", file=sys.stderr)
        return False
    return True


def check_env_var(name, description, required=True):
    value = os.getenv(name)
    if value:
        print(f"✅ {description} present at {value}")
        return True
    if required:
        print(f"❌ {description} environment variable '{name}' not set", file=sys.stderr)
    else:
        print(f"⚠️ {description} environment variable '{name}' not set, but optional")
    return False


def main():
    success = True
    # PowerShell
    if not check_executable("pwsh", "-NoProfile -Command Get-Host"):
        # Try powershell
        if not check_executable("powershell", "-NoProfile -Command Get-Host"):
            success = False
    # TinyCC
    if not check_executable("tcc", "-v"):
        success = False
    # Environment variables
    if not check_env_var("WPM_TCC_ROOT", "TinyCC root via WPM", required=True):
        success = False
    if not check_env_var("WPM_WCRT_ROOT", "WCRT root via WPM", required=True):
        success = False
    # Check WCRT headers and startup object paths
    wcrt_root = os.getenv("WPM_WCRT_ROOT") or os.getenv("ProgramFiles") + "\\WCRT"
    stdio_path = os.path.join(wcrt_root, "include", "stdio.h")
    if os.path.isfile(stdio_path):
        print(f"✅ WCRT headers exist at {stdio_path}")
    else:
        print(f"❌ WCRT headers missing at {stdio_path}", file=sys.stderr)
        success = False
    startup_path = os.path.join(wcrt_root, "lib", "wcrt-startup-console.o")
    if os.path.isfile(startup_path):
        print(f"✅ WCRT console startup object exists at {startup_path}")
    else:
        print(f"❌ WCRT console startup object missing at {startup_path}", file=sys.stderr)
        success = False
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()
