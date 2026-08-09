if(NOT DEFINED KERTEX_FORMAT OR NOT EXISTS "${KERTEX_FORMAT}")
  message(FATAL_ERROR "KERTEX_FORMAT must name an existing format dump")
endif()
if(NOT DEFINED KERTEX_PROVENANCE OR NOT DEFINED KERTEX_ARCH)
  message(FATAL_ERROR "KERTEX_PROVENANCE and KERTEX_ARCH are required")
endif()
file(SHA256 "${KERTEX_FORMAT}" _format_sha256)
file(WRITE "${KERTEX_PROVENANCE}"
  "architecture=${KERTEX_ARCH}\n"
  "format-sha256=${_format_sha256}\n"
  "latex-kernel=2020-10-01-PL4\n"
  "format-date=2026-01-01\n")
