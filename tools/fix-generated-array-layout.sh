#!/bin/sh
set -eu

if test $# -ne 1; then
  echo "usage: $0 GENERATED_DIRECTORY" >&2
  exit 2
fi

output=$(realpath "$1")

# pp2rc represents Pascal arrays with nonzero lower bounds by forming C
# pointers before their backing arrays. Besides being undefined C, TinyCC's
# ARM64 backend materializes the negative byte displacement through a W
# register. The resulting zero-extension turns the displacement into a value
# exactly 4 GiB too large. Keep the generated indexing unchanged, but reserve
# unused leading elements so every logical Pascal index is a valid C index.
for tex_header in \
  "$output/tex/bin1/initex/texd.h" \
  "$output/tex/bin1/virtex/texd.h"
do
  if ! grep -q -F '#define xeqlevel (zzzad -422593)' "$tex_header" ||
     ! grep -q -F '  zzzad[844]  ;' "$tex_header" ||
     ! grep -q -F '#define hash (zzzae -514)' "$tex_header" ||
     ! grep -q -F '  zzzae[419697]  ;' "$tex_header"
  then
    echo "Unexpected generated TeX array layout: $tex_header" >&2
    exit 3
  fi
  sed -i \
    -e 's/^#define xeqlevel (zzzad -422593)$/#define xeqlevel zzzad/' \
    -e 's/^[[:space:]]*zzzad\[844\][[:space:]]*;[[:space:]]*$/  zzzad[423437]  ;/' \
    -e 's/^#define hash (zzzae -514)$/#define hash zzzae/' \
    -e 's/^[[:space:]]*zzzae\[419697\][[:space:]]*;[[:space:]]*$/  zzzae[420211]  ;/' \
    "$tex_header"
  if ! grep -q -F '#define xeqlevel zzzad' "$tex_header" ||
     ! grep -q -F 'zzzad[423437]' "$tex_header" ||
     ! grep -q -F '#define hash zzzae' "$tex_header" ||
     ! grep -q -F 'zzzae[420211]' "$tex_header"
  then
    echo "Failed to rewrite generated TeX array layout: $tex_header" >&2
    exit 4
  fi
done

for mf_header in "$output"/mf/bin1/*/mfd.h; do
  sed -i \
    -e 's/^#define bignodesize (zzzaa -13)$/#define bignodesize zzzaa/' \
    -e 's/^[[:space:]]*zzzaa\[2\][[:space:]]*;[[:space:]]*$/  zzzaa[15]  ;/' \
    -e 's/^#define maxc (zzzab -17)$/#define maxc zzzab/' \
    -e 's/^[[:space:]]*zzzab\[2\][[:space:]]*;[[:space:]]*$/  zzzab[19]  ;/' \
    -e 's/^#define maxptr (zzzac -17)$/#define maxptr zzzac/' \
    -e 's/^[[:space:]]*zzzac\[2\][[:space:]]*;[[:space:]]*$/  zzzac[19]  ;/' \
    -e 's/^#define maxlink (zzzad -17)$/#define maxlink zzzad/' \
    -e 's/^[[:space:]]*zzzad\[2\][[:space:]]*;[[:space:]]*$/  zzzad[19]  ;/' \
    "$mf_header"
  grep -q -F 'zzzaa[15]' "$mf_header" && grep -q -F 'zzzad[19]' "$mf_header" || {
    echo "Failed to rewrite generated METAFONT array layout: $mf_header" >&2
    exit 5
  }
done

for mp_header in "$output"/mp/bin1/*/mpd.h; do
  sed -i \
    -e 's/^#define bignodesize (zzzaa -12)$/#define bignodesize zzzaa/' \
    -e 's/^[[:space:]]*zzzaa\[3\][[:space:]]*;[[:space:]]*$/  zzzaa[15]  ;/' \
    -e 's/^#define sector0 (zzzab -12)$/#define sector0 zzzab/' \
    -e 's/^[[:space:]]*zzzab\[3\][[:space:]]*;[[:space:]]*$/  zzzab[15]  ;/' \
    -e 's/^#define sectoroffset (zzzac -5)$/#define sectoroffset zzzac/' \
    -e 's/^[[:space:]]*zzzac\[9\][[:space:]]*;[[:space:]]*$/  zzzac[14]  ;/' \
    -e 's/^#define maxc (zzzad -17)$/#define maxc zzzad/' \
    -e 's/^[[:space:]]*zzzad\[2\][[:space:]]*;[[:space:]]*$/  zzzad[19]  ;/' \
    -e 's/^#define maxptr (zzzae -17)$/#define maxptr zzzae/' \
    -e 's/^[[:space:]]*zzzae\[2\][[:space:]]*;[[:space:]]*$/  zzzae[19]  ;/' \
    -e 's/^#define maxlink (zzzaf -17)$/#define maxlink zzzaf/' \
    -e 's/^[[:space:]]*zzzaf\[2\][[:space:]]*;[[:space:]]*$/  zzzaf[19]  ;/' \
    "$mp_header"
  grep -q -F 'zzzaa[15]' "$mp_header" && grep -q -F 'zzzaf[19]' "$mp_header" || {
    echo "Failed to rewrite generated MetaPost array layout: $mp_header" >&2
    exit 6
  }
done

for prote_header in \
  "$output/prote/bin1/ini/texd.h" \
  "$output/prote/bin1/vir/texd.h"
do
  sed -i \
    -e 's/^#define xeqlevel (zzzad -422599)$/#define xeqlevel zzzad/' \
    -e 's/^[[:space:]]*zzzad\[857\][[:space:]]*;[[:space:]]*$/  zzzad[423456]  ;/' \
    -e 's/^#define hash (zzzae -514)$/#define hash zzzae/' \
    -e 's/^[[:space:]]*zzzae\[419698\][[:space:]]*;[[:space:]]*$/  zzzae[420212]  ;/' \
    "$prote_header"
  grep -q -F 'zzzad[423456]' "$prote_header" && grep -q -F 'zzzae[420212]' "$prote_header" || {
    echo "Failed to rewrite generated Prote array layout: $prote_header" >&2
    exit 7
  }
done

for etex_header in \
  "$output/etex/bin1/einitex/texd.h" \
  "$output/etex/bin1/evirtex/texd.h"
do
  sed -i \
    -e 's/^#define xeqlevel (zzzad -422598)$/#define xeqlevel zzzad/' \
    -e 's/^[[:space:]]*zzzad\[855\][[:space:]]*;[[:space:]]*$/  zzzad[423453]  ;/' \
    -e 's/^#define hash (zzzae -514)$/#define hash zzzae/' \
    -e 's/^[[:space:]]*zzzae\[419697\][[:space:]]*;[[:space:]]*$/  zzzae[420211]  ;/' \
    "$etex_header"
  grep -q -F 'zzzad[423453]' "$etex_header" && grep -q -F 'zzzae[420211]' "$etex_header" || {
    echo "Failed to rewrite generated e-TeX array layout: $etex_header" >&2
    exit 8
  }
done
