import re

# Read CMakeLists.txt to extract KERTEX_PACKAGE_VERSION
with open("CMakeLists.txt", "r", encoding="utf-8") as f:
    content = f.read()
match = re.search(r'set\(KERTEX_PACKAGE_VERSION\s+"([^"]+)"', content)
assert match, "KERTEX_PACKAGE_VERSION not found in CMakeLists.txt"
version = match.group(1)
# Must be semver: major.minor.patch optionally -ci.<num> or pre-release
# SemVer regex: digits.digits.digits optionally -anything
semver_regex = r'^\d+\.\d+\.\d+(?:-[A-Za-z0-9\.]+)?$'
assert re.match(semver_regex, version), f"KERTEX_PACKAGE_VERSION '{version}' is not a valid semver"
print("KERTEX_PACKAGE_VERSION", version)
