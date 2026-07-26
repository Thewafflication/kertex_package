#!/bin/sh
set -eu

if test $# -ne 3; then
  echo "usage: $0 BUNDLE REPOSITORY_ROOT OUTPUT_DIRECTORY" >&2
  exit 2
fi

bundle=$(realpath "$1")
repo=$(realpath "$2")
output=$3
work=${KERTEX_GENERATOR_WORK:-"$repo/out/generator-work"}

rm -rf "$work"
mkdir -p "$work/src" "$work/obj" "$work/install" "$output"
output=$(realpath "$output")
work=$(realpath "$work")
tar -xf "$bundle" -C "$work/src"

for archive in "$work/src"/*.tar.gz; do
  tar -xzf "$archive" -C "$work/src"
done

# Generate from the checked-out kertex_T tree so local changes and the
# submodule revision under test, rather than the bundled release copy, win.
rm -rf "$work/src/kertex_T"
cp -a "$repo/kertex_T" "$work/src/kertex_T"

conf="$work/kertex.conf"
cat >"$conf" <<EOF
USER0=$(id -un)
GROUP0=$(id -gn)
TARGETOPTDIR=$work/install
OBJDIRPREFIX=$work/obj
WITH_2D_MF=NO
HUGETEX=NO
EOF

cd "$work/src/kertex_M"
matrix_obj=$(../risk_comp/sys/posix/sh1/rkconfig "$conf")
make -C "$matrix_obj" SAVE_SPACE=NO all

cd "$work/src/kertex_T"
target_obj=$(../risk_comp/sys/posix/sh1/rkconfig "$conf")
make -C "$target_obj" SAVE_SPACE=NO all

rm -rf "$output"
mkdir -p "$output"
cp -a "$target_obj/." "$output/"
printf '%s\n' "$target_obj" >"$output/.generator-origin"
