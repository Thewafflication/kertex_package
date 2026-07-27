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

# The upstream project map intentionally leaves the large engines disabled.
# Enable the two TeX directories required by this native Plain TeX slice so
# rkconfig creates their object directories and the generated split C files.
sed -i \
  -e 's|^#@ d \* \* \$PROJECTDIR/tex/bin1/initex \*|@ d * * $PROJECTDIR/tex/bin1/initex *|' \
  -e 's|^#@ d \* \* \$PROJECTDIR/tex/bin1/virtex \*|@ d * * $PROJECTDIR/tex/bin1/virtex *|' \
  "$work/src/kertex_T/conf/KERTEX_T.map"

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

# Preserve the runtime inputs alongside the generated C tree.  The native
# build consumes this relocatable layout instead of reaching back into the
# temporary POSIX generator workspace.
mkdir -p "$output/runtime/tex" "$output/runtime/pool" \
  "$output/runtime/fonts/tfm"
cp "$work/src/knuth/lib/plain.tex" "$output/runtime/tex/plain.tex"
cp "$work/src/knuth/lib/hyphen.tex" "$output/runtime/tex/hyphen.tex"
cp "$work/src/knuth/lib/null.tex" "$output/runtime/tex/null.tex"
cp "$repo/kertex_T/tex/lib/hyperbasics.tex" \
  "$output/runtime/tex/hyperbasics.tex"
cp "$target_obj/tex/bin1/initex/tex.pool" "$output/runtime/pool/tex.pool"

# Plain TeX loads its Computer Modern metrics while plain.fmt is created.
# The kerTeX build produces those metrics in the object tree; flattening the
# filenames matches the root font search path used by libweb.
find "$target_obj" "$work/src/knuth" "$work/src/ams" \
  -type f -name '*.tfm' -exec cp '{}' "$output/runtime/fonts/tfm/" \;

# The Computer Modern source archive supplies Type 1 outlines and AFM files,
# not prebuilt TFM files.  Convert every available CM metric so plain.tex can
# load its standard font family while the format is dumped and documents run.
for afm in "$work/src/knuth/cm/ps-type1/"*.afm; do
  font=${afm##*/}
  font=${font%.afm}
  # ENCSUBDIR makes afm2tfm look below each font root's enc directory.
  KERTEXFONTS="$repo/kertex_T/fonts" \
    "$target_obj/fontware/bin1/afm2tfm/afm2tfm" \
      "$afm" "$output/runtime/fonts/tfm/$font.tfm"
done

# manfnt has no AFM; generate its metric with METAFONT. Build the standard
# plain base first, then run virmf explicitly against that base.
mkdir -p "$work/mf"
(
  cd "$work/mf"
  KERTEXPOOL="$target_obj/mf/bin1/inimf" \
  KERTEXINPUTS="$work/src/knuth/lib:$repo/kertex_T/mf/lib:$work/src/knuth/cm" \
  KERTEXDUMP="$work/mf" \
    "$target_obj/mf/bin1/inimf/inimf" \
      '\input plain \input modes \dump'
  KERTEXPOOL="$target_obj/mf/bin1/inimf" \
  KERTEXINPUTS="$work/src/knuth/lib:$repo/kertex_T/mf/lib:$work/src/knuth/cm" \
  KERTEXDUMP="$work/mf" \
    "$target_obj/mf/bin1/virmf/virmf" \
      '&plain \mode=ljfour; nonstopmode; input manfnt'
)
test -s "$work/mf/manfnt.tfm"
cp "$work/mf/manfnt.tfm" "$output/runtime/fonts/tfm/manfnt.tfm"

# TeX format dumps contain TeX's fixed-width internal words and are portable
# across these little-endian targets.  Generate Plain TeX on the POSIX host so
# ARM64 packages do not need to execute an ARM64 binary on an x64 CI runner.
mkdir -p "$output/runtime/lib" "$work/format"
(
  cd "$work/format"
  KERTEXPOOL="$output/runtime/pool" \
  KERTEXINPUTS="$output/runtime/tex" \
  KERTEXFONTS="$output/runtime/fonts/tfm" \
  KERTEXDUMP="$work/format" \
    "$target_obj/tex/bin1/initex/initex" '\input plain \dump'
)
test -s "$work/format/plain.fmt"
cp "$work/format/plain.fmt" "$output/runtime/lib/plain.fmt"

# pp2rc preserves the header pathname passed by the RISK makefiles. Those
# paths point into this temporary Linux workspace and are invalid when the C
# artifact is compiled on Windows. Convert them to repository-relative paths.
find "$output" -type f \( -name '*.c' -o -name '*.h' \) -exec \
  sed -i \
    -e "s|$work/src/kertex_T/|kertex_T/|g" \
    -e "s|$target_obj/||g" \
    -e "s|$work/install/share/kertex|share/kertex|g" \
    -e "s|$work/install/bin/kertex|bin/kertex|g" {} +
if grep -R -n -F "$work/" "$output" --include='*.c' --include='*.h'; then
  echo 'Generated C still contains non-relocatable generator paths' >&2
  exit 4
fi

printf '%s\n' "$target_obj" >"$output/.generator-origin"
