set(CMAKE_SYSTEM_NAME Windows)

if(NOT DEFINED KERTEX_ARCH)
  set(KERTEX_ARCH x86)
endif()

if(KERTEX_ARCH STREQUAL "x86")
  set(_kertex_tcc_driver i386-win32-tcc.exe)
  set(CMAKE_SYSTEM_PROCESSOR x86)
elseif(KERTEX_ARCH STREQUAL "x64")
  set(_kertex_tcc_driver x86_64-win32-tcc.exe)
  set(CMAKE_SYSTEM_PROCESSOR AMD64)
elseif(KERTEX_ARCH STREQUAL "arm64")
  set(_kertex_tcc_driver arm64-win32-tcc.exe)
  set(CMAKE_SYSTEM_PROCESSOR ARM64)
else()
  message(FATAL_ERROR "KERTEX_ARCH must be x86, x64, or arm64")
endif()

if(DEFINED ENV{WPM_TCC_ROOT} AND NOT "$ENV{WPM_TCC_ROOT}" STREQUAL "")
  file(TO_CMAKE_PATH "$ENV{WPM_TCC_ROOT}" KERTEX_TCC_ROOT)
else()
  file(TO_CMAKE_PATH "$ENV{ProgramFiles}/TinyCC" _kertex_tcc_install_root)
  file(GLOB _kertex_tcc_versions LIST_DIRECTORIES TRUE "${_kertex_tcc_install_root}/*")
  list(SORT _kertex_tcc_versions COMPARE NATURAL ORDER DESCENDING)
  foreach(_candidate IN LISTS _kertex_tcc_versions)
    if(EXISTS "${_candidate}/${_kertex_tcc_driver}")
      set(KERTEX_TCC_ROOT "${_candidate}")
      break()
    endif()
  endforeach()
endif()

if(NOT KERTEX_TCC_ROOT)
  message(FATAL_ERROR "WPM TinyCC package not found; install tinycc or set WPM_TCC_ROOT")
endif()

set(CMAKE_C_COMPILER "${KERTEX_TCC_ROOT}/${_kertex_tcc_driver}" CACHE FILEPATH "WPM TinyCC compiler")
find_program(_kertex_powershell powershell.exe REQUIRED)
get_filename_component(_kertex_archiver "${CMAKE_CURRENT_LIST_DIR}/../TinyCCArchiver.ps1" ABSOLUTE)
string(REPLACE "'" "''" _kertex_tcc_literal "${CMAKE_C_COMPILER}")
execute_process(
  COMMAND "${_kertex_powershell}" -NoProfile -Command
    "[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('${_kertex_tcc_literal}'))"
  OUTPUT_VARIABLE _kertex_tcc_base64
  OUTPUT_STRIP_TRAILING_WHITESPACE
  COMMAND_ERROR_IS_FATAL ANY
)
set(CMAKE_AR "${_kertex_powershell}" CACHE FILEPATH "PowerShell archiver launcher")
set(CMAKE_C_ARCHIVE_CREATE "<CMAKE_AR> -NoProfile -ExecutionPolicy Bypass -File \"${_kertex_archiver}\" ${_kertex_tcc_base64} rc <TARGET> <OBJECTS>")
set(CMAKE_C_ARCHIVE_APPEND "<CMAKE_AR> -NoProfile -ExecutionPolicy Bypass -File \"${_kertex_archiver}\" ${_kertex_tcc_base64} r <TARGET> <OBJECTS>")
set(CMAKE_C_ARCHIVE_FINISH "")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-Wl,-subsystem=console")
