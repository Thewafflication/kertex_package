import re
import pathlib

def test_minimum_required():
    cmake_file = pathlib.Path("CMakeLists.txt")
    lines = cmake_file.read_text().splitlines()[:20]
    version = None
    for line in lines:
        m = re.search(r"cmake_minimum_required\s*\((?:[^\s]+)\s*([0-9]+\.[0-9]+)\)", line)
        if m:
            version = m.group(1)
            break
    assert version is not None, "cmake_minimum_required not found"
    major, minor = map(int, version.split("."))
    assert (major, minor) >= (3, 21), f"CMake version {version} < 3.21"
