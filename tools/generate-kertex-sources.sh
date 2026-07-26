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

# The release archive contains generated webmerged*.ch inputs that are
# intentionally absent from Git. Preserve that tree, then overlay the checked
# out submodule so its revision and local changes win for tracked sources.
cp -a "$repo/kertex_T/." "$work/src/kertex_T/"

required_merged_inputs='
tex/bin1/webmergedBIG.ch
tex/bin1/webmergedTRIP.ch
mf/bin1/webmergedIniBIG.ch
mf/bin1/webmergedBIG.ch
mf/bin1/webmergedTRAP.ch
mp/bin1/webmergedBIG.ch
mp/bin1/webmergedTWIST.ch
texware/bin1/bibtex/webmergedBIG.ch
etex/bin1/webmergedBIG.ch
etex/bin1/webmergedETRIP.ch
prote/bin1/webmergedBIG.ch
prote/bin1/webmergedSELLETTE.ch
'
missing_inputs=
for relative_path in $required_merged_inputs; do
  if ! test -s "$work/src/kertex_T/$relative_path"; then
    missing_inputs="$missing_inputs $relative_path"
  fi
done
if test -n "$missing_inputs"; then
  echo "kerTeX release bundle is missing required generated inputs:$missing_inputs" >&2
  exit 3
fi

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

# pp2rc preserves the header pathname passed by the RISK makefiles. Those
# paths point into this temporary Linux workspace and are invalid when the C
# artifact is compiled on Windows. Convert them to repository-relative paths.
find "$output" -type f \( -name '*.c' -o -name '*.h' \) -exec \
  sed -i \
    -e "s|$work/src/kertex_T/|kertex_T/|g" \
    -e "s|$target_obj/||g" {} +
if grep -R -n -F "$work/" "$output" --include='*.c' --include='*.h'; then
  echo 'Generated C still contains non-relocatable generator paths' >&2
  exit 4
fi

printf '%s\n' "$target_obj" >"$output/.generator-origin"
