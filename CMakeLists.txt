cmake_minimum_required(VERSION 3.21)
project(kertex_windows LANGUAGES C)

include(CTest)

find_program(KERTEX_PWSH_EXECUTABLE NAMES pwsh.exe pwsh powershell.exe REQUIRED)
add_custom_target(download-sources
  COMMAND "${KERTEX_PWSH_EXECUTABLE}" -NoProfile -ExecutionPolicy Bypass
    -File "${CMAKE_CURRENT_SOURCE_DIR}/tools/Get-KertexBundle.ps1"
  WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
  COMMENT "Downloading and verifying the official kerTeX source bundle"
  VERBATIM
)

set(KERTEX_ARCH "x86" CACHE STRING "Target architecture: x86, x64, or arm64")
set_property(CACHE KERTEX_ARCH PROPERTY STRINGS x86 x64 arm64)
set(KERTEX_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/kertex_T" CACHE PATH "kertex_T source directory")
set(KERTEX_GENERATED_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/out/generated" CACHE PATH "Host-generated kerTeX object tree")
set(KERTEX_RUNTIME_ROOT "${KERTEX_GENERATED_ROOT}/runtime" CACHE PATH "Host-generated kerTeX runtime tree")
set(KERTEX_PACKAGE_VERSION "0.0.0-local" CACHE STRING "Semantic product and WPM package version")
if(NOT KERTEX_PACKAGE_VERSION MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)([-+].*)?$")
  message(FATAL_ERROR "KERTEX_PACKAGE_VERSION must be semantic: ${KERTEX_PACKAGE_VERSION}")
endif()
set(_kertex_version_major "${CMAKE_MATCH_1}")
set(_kertex_version_minor "${CMAKE_MATCH_2}")
set(_kertex_version_patch "${CMAKE_MATCH_3}")
set(_kertex_version_build 0)
if(KERTEX_PACKAGE_VERSION MATCHES "-ci\\.([0-9]+)")
  set(_kertex_version_build "${CMAKE_MATCH_1}")
endif()
foreach(_component _kertex_version_major _kertex_version_minor _kertex_version_patch _kertex_version_build)
  if(${_component} GREATER 65535)
    set(${_component} 65535)
  endif()
endforeach()
set(KERTEX_FILE_VERSION
  "${_kertex_version_major},${_kertex_version_minor},${_kertex_version_patch},${_kertex_version_build}")
if(KERTEX_PACKAGE_VERSION MATCHES "-")
  set(KERTEX_FILE_FLAGS VS_FF_PRERELEASE)
else()
  set(KERTEX_FILE_FLAGS 0x0L)
endif()
file(STRINGS "${KERTEX_SOURCE_DIR}/CID" _kertex_cid_version REGEX "^VERSION:" LIMIT_COUNT 1)
string(REGEX REPLACE "^VERSION:[ \\t]*" "" KERTEX_SOURCE_VERSION "${_kertex_cid_version}")
execute_process(COMMAND git -C "${CMAKE_CURRENT_SOURCE_DIR}" rev-parse --short=8 HEAD
  OUTPUT_VARIABLE KERTEX_SOURCE_REVISION OUTPUT_STRIP_TRAILING_WHITESPACE
  COMMAND_ERROR_IS_FATAL ANY)

find_program(KERTEX_RC_EXECUTABLE NAMES rc.exe)
if(NOT KERTEX_RC_EXECUTABLE)
  file(GLOB_RECURSE _kertex_rc_candidates
    "$ENV{ProgramFiles\(x86\)}/Windows Kits/10/bin/*/x64/rc.exe")
  list(SORT _kertex_rc_candidates COMPARE NATURAL ORDER DESCENDING)
  if(_kertex_rc_candidates)
    list(GET _kertex_rc_candidates 0 KERTEX_RC_EXECUTABLE)
  endif()
endif()
if(NOT EXISTS "${KERTEX_RC_EXECUTABLE}")
  message(FATAL_ERROR "The Windows SDK resource compiler rc.exe is required")
endif()

if(NOT CMAKE_C_COMPILER_ID STREQUAL "TinyCC")
  message(FATAL_ERROR "Native kerTeX Windows builds require the WPM TinyCC package")
endif()

if(DEFINED ENV{WPM_WCRT_ROOT} AND NOT "$ENV{WPM_WCRT_ROOT}" STREQUAL "")
  file(TO_CMAKE_PATH "$ENV{WPM_WCRT_ROOT}" KERTEX_WCRT_ROOT)
else()
  file(TO_CMAKE_PATH "$ENV{ProgramFiles}/WCRT" _kertex_wcrt_install_root)
  file(GLOB _kertex_wcrt_versions LIST_DIRECTORIES TRUE "${_kertex_wcrt_install_root}/*")
  list(SORT _kertex_wcrt_versions COMPARE NATURAL ORDER DESCENDING)
  foreach(_candidate IN LISTS _kertex_wcrt_versions)
    if(EXISTS "${_candidate}/lib/libwcrt.a" AND EXISTS "${_candidate}/include/stdio.h")
      set(KERTEX_WCRT_ROOT "${_candidate}")
      break()
    endif()
  endforeach()
endif()
if(NOT KERTEX_WCRT_ROOT)
  message(FATAL_ERROR "WPM WCRT package not found; install wcrt or set WPM_WCRT_ROOT")
endif()
set(KERTEX_WCRT_CONSOLE_STARTUP "${KERTEX_WCRT_ROOT}/lib/wcrt-startup-console.o")
if(NOT EXISTS "${KERTEX_WCRT_CONSOLE_STARTUP}")
  message(FATAL_ERROR
    "WCRT console startup object not found: ${KERTEX_WCRT_CONSOLE_STARTUP}. "
    "Install WCRT 0.9.4 or newer.")
endif()

message(STATUS "kerTeX target: ${KERTEX_ARCH}")
message(STATUS "kerTeX product version: ${KERTEX_PACKAGE_VERSION} (${KERTEX_FILE_VERSION})")
message(STATUS "TinyCC package: ${KERTEX_TCC_ROOT}")
message(STATUS "WCRT package: ${KERTEX_WCRT_ROOT}")

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/include")
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/cmake/kertex.h.in" "${CMAKE_BINARY_DIR}/include/kertex.h" @ONLY)
include_directories(BEFORE "${KERTEX_WCRT_ROOT}/include")
include_directories(BEFORE "${CMAKE_BINARY_DIR}/include")
include_directories("${KERTEX_SOURCE_DIR}/lib1/pascal")

add_library(kertex_wcrt INTERFACE)
target_compile_definitions(kertex_wcrt INTERFACE T_TETRA=int)
target_compile_options(kertex_wcrt INTERFACE -std=c99)
target_link_options(kertex_wcrt INTERFACE -nostdlib -Wl,-nostdlib)
target_link_libraries(kertex_wcrt INTERFACE
  "${KERTEX_WCRT_CONSOLE_STARTUP}"
  "${KERTEX_WCRT_ROOT}/lib/libwcrt.a"
)
if(KERTEX_ARCH STREQUAL "x86")
  target_compile_definitions(kertex_wcrt INTERFACE WINVER=0x0500 _WIN32_WINNT=0x0500)
  target_link_libraries(kertex_wcrt INTERFACE "${KERTEX_TCC_ROOT}/lib/i386-win32-libtcc1.a")
elseif(KERTEX_ARCH STREQUAL "x64")
  target_link_libraries(kertex_wcrt INTERFACE "${KERTEX_TCC_ROOT}/lib/x86_64-win32-libtcc1.a")
else()
  target_link_libraries(kertex_wcrt INTERFACE "${KERTEX_TCC_ROOT}/lib/arm64-win32-libtcc1.a")
endif()
target_link_libraries(kertex_wcrt INTERFACE "${KERTEX_TCC_ROOT}/lib/kernel32.def")

function(kertex_program name)
  set(KERTEX_RESOURCE_NAME "${name}")
  file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/resources")
  set(_resource_source "${CMAKE_BINARY_DIR}/resources/${name}.rc")
  set(_resource_object "${CMAKE_BINARY_DIR}/resources/${name}.res")
  configure_file("${CMAKE_CURRENT_SOURCE_DIR}/cmake/kertex.rc.in" "${_resource_source}" @ONLY)
  add_custom_command(OUTPUT "${_resource_object}"
    COMMAND "${KERTEX_RC_EXECUTABLE}" /nologo "/fo${_resource_object}" "${_resource_source}"
    DEPENDS "${_resource_source}"
    COMMENT "Compiling ${name}.exe version information"
    VERBATIM)
  add_custom_target(${name}_resource DEPENDS "${_resource_object}")
  add_executable(${name} ${ARGN})
  add_dependencies(${name} ${name}_resource)
  add_custom_command(TARGET ${name} POST_BUILD
    COMMAND "${KERTEX_PWSH_EXECUTABLE}" -NoProfile -ExecutionPolicy Bypass
      -File "${CMAKE_CURRENT_SOURCE_DIR}/tools/Add-Win32Resource.ps1"
      -Binary "$<TARGET_FILE:${name}>" -CompiledResource "${_resource_object}"
    COMMENT "Embedding ${name}.exe version information"
    VERBATIM)
  set_property(TARGET ${name} PROPERTY C_STANDARD 99)
  set_property(TARGET ${name} PROPERTY C_STANDARD_REQUIRED ON)
  set_property(TARGET ${name} PROPERTY C_EXTENSIONS ON)
  target_link_libraries(${name} PRIVATE kertex_wcrt)
  install(TARGETS ${name} RUNTIME DESTINATION bin)
endfunction()

kertex_program(mptotex "${KERTEX_SOURCE_DIR}/mpware/bin1/mptotex/main.c")
kertex_program(mptotr "${KERTEX_SOURCE_DIR}/mpware/bin1/mptotr/main.c")

if(EXISTS "${KERTEX_GENERATED_ROOT}/web/bin1/tangle/tangle.c")
  add_library(kertex_pascal STATIC
    "${KERTEX_SOURCE_DIR}/lib1/pascal/lib.c"
  )
  target_include_directories(kertex_pascal PUBLIC "${KERTEX_SOURCE_DIR}/lib1/pascal")
  target_link_libraries(kertex_pascal PUBLIC kertex_wcrt)

  add_library(kertex_web STATIC
    "${KERTEX_SOURCE_DIR}/lib1/web/pascalh.c"
    "${KERTEX_SOURCE_DIR}/lib1/web/argfmt.c"
    "${KERTEX_SOURCE_DIR}/lib1/web/inputln.c"
    "${KERTEX_SOURCE_DIR}/lib1/web/date.c"
    "${KERTEX_SOURCE_DIR}/lib1/web/print.c"
    "${KERTEX_SOURCE_DIR}/lib1/web/farithm.c"
    "${KERTEX_SOURCE_DIR}/lib1/web/file.c"
    "${KERTEX_SOURCE_DIR}/lib1/web/md5.c"
    "${KERTEX_SOURCE_DIR}/sys/lib1/web/dumb.c"
  )
  target_include_directories(kertex_web PUBLIC
    "${KERTEX_SOURCE_DIR}/lib1/web"
    "${KERTEX_SOURCE_DIR}/lib1/pascal"
  )
  target_compile_definitions(kertex_web PRIVATE ENDIANNESS=1234)
  target_link_libraries(kertex_web PUBLIC kertex_pascal kertex_wcrt)

  function(kertex_generated_program name relative_directory)
    set(_source "${KERTEX_GENERATED_ROOT}/${relative_directory}/${name}.c")
    if(EXISTS "${_source}")
      kertex_program(${name} "${_source}" ${ARGN})
      target_include_directories(${name} PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}"
        "${KERTEX_GENERATED_ROOT}"
        "${KERTEX_GENERATED_ROOT}/${relative_directory}"
        "${KERTEX_SOURCE_DIR}/${relative_directory}"
        "${KERTEX_SOURCE_DIR}/lib1/web"
        "${KERTEX_SOURCE_DIR}/lib1/pascal"
      )
      target_link_libraries(${name} PRIVATE kertex_web kertex_pascal)
    else()
      message(WARNING "Generated source missing: ${_source}")
    endif()
  endfunction()

  kertex_generated_program(tangle web/bin1/tangle)
  kertex_generated_program(weave web/bin1/weave)
  kertex_generated_program(pooltype webware/bin1/pooltype)
  kertex_generated_program(gftype mfware/bin1/gftype)
  kertex_generated_program(gftodvi mfware/bin1/gftodvi)
  kertex_generated_program(mft mfware/bin1/mft
    "${KERTEX_SOURCE_DIR}/mfware/bin1/mft/extra.c")
  kertex_generated_program(tftopl texware/bin1/tftopl)
  kertex_generated_program(pltotf texware/bin1/pltotf)
  kertex_generated_program(bibtex texware/bin1/bibtex
    "${KERTEX_SOURCE_DIR}/texware/bin1/bibtex/extra.c")
  kertex_generated_program(dvitype dviware/bin1/dvitype)
  kertex_generated_program(vftovp fontware/bin1/vftovp)
  kertex_generated_program(vptovf fontware/bin1/vptovf)
  kertex_generated_program(gftopk fontware/bin1/gftopk)
  kertex_generated_program(dvitomp mpware/bin1/dvitomp)

  # TeX is emitted by pp2rc as a family of split C translation units rather
  # than as the single <program>.c used by the smaller WEB utilities above.
  set(_kertex_tex_init_dir "${KERTEX_GENERATED_ROOT}/tex/bin1/initex")
  set(_kertex_tex_vir_dir "${KERTEX_GENERATED_ROOT}/tex/bin1/virtex")

  function(kertex_tex_engine name generated_directory extra_source)
    set(_engine_sources "${generated_directory}/itex.c")
    foreach(_part RANGE 0 11)
      list(APPEND _engine_sources "${generated_directory}/tex${_part}.c")
    endforeach()
    if(NOT EXISTS "${generated_directory}/itex.c")
      message(WARNING "Generated TeX engine sources missing: ${generated_directory}")
      return()
    endif()
    kertex_program(${name} ${_engine_sources} "${extra_source}")
    target_include_directories(${name} PRIVATE
      "${CMAKE_CURRENT_SOURCE_DIR}"
      "${KERTEX_GENERATED_ROOT}"
      "${generated_directory}"
      "${KERTEX_SOURCE_DIR}/tex/bin1"
      "${KERTEX_SOURCE_DIR}/lib1/web"
      "${KERTEX_SOURCE_DIR}/lib1/pascal")
    target_compile_definitions(${name} PRIVATE STAT)
    target_link_libraries(${name} PRIVATE kertex_web kertex_pascal)
  endfunction()

  kertex_tex_engine(initex "${_kertex_tex_init_dir}"
    "${KERTEX_SOURCE_DIR}/tex/bin1/initex/extra.c")
  if(TARGET initex)
    target_compile_definitions(initex PRIVATE INITEX)
    if(KERTEX_ARCH STREQUAL "arm64")
      target_compile_options(initex PRIVATE -g)
    endif()
  endif()
  set(KERTEX_NATIVE_RUNTIME_ROOT "${CMAKE_BINARY_DIR}/runtime")
  set(_kertex_format_work "${CMAKE_BINARY_DIR}/format-work")
  set(_kertex_native_format "${KERTEX_NATIVE_RUNTIME_ROOT}/lib/plain.fmt")
  file(MAKE_DIRECTORY "${_kertex_format_work}" "${KERTEX_NATIVE_RUNTIME_ROOT}/lib")
  if(TARGET initex
      AND EXISTS "${KERTEX_RUNTIME_ROOT}/pool/tex.pool"
      AND EXISTS "${KERTEX_RUNTIME_ROOT}/tex/plain.tex"
      AND EXISTS "${KERTEX_RUNTIME_ROOT}/tex/hyphen.tex"
      AND IS_DIRECTORY "${KERTEX_RUNTIME_ROOT}/fonts/tfm")
    file(GLOB _kertex_tfm_files CONFIGURE_DEPENDS
      "${KERTEX_RUNTIME_ROOT}/fonts/tfm/*.tfm")
    add_custom_command(OUTPUT "${_kertex_native_format}"
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${KERTEX_RUNTIME_ROOT}/pool/tex.pool" "${_kertex_format_work}/tex.pool"
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${KERTEX_RUNTIME_ROOT}/tex/plain.tex" "${_kertex_format_work}/plain.tex"
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${KERTEX_RUNTIME_ROOT}/tex/hyphen.tex" "${_kertex_format_work}/hyphen.tex"
      COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${KERTEX_RUNTIME_ROOT}/fonts/tfm" "${_kertex_format_work}/tfm"
      COMMAND "${CMAKE_COMMAND}" -E env
        "KERTEX_LIBDIR=." "KERTEX_BINDIR=." "KERTEXPOOL=."
        "KERTEXINPUTS=." "KERTEXFONTS=." "KERTEXDUMP=."
        "$<TARGET_FILE:initex>" "\\input plain \\dump"
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${_kertex_format_work}/plain.fmt" "${_kertex_native_format}"
      WORKING_DIRECTORY "${_kertex_format_work}"
      DEPENDS initex
        "${KERTEX_RUNTIME_ROOT}/pool/tex.pool"
        "${KERTEX_RUNTIME_ROOT}/tex/plain.tex"
        "${KERTEX_RUNTIME_ROOT}/tex/hyphen.tex"
        ${_kertex_tfm_files}
      COMMENT "Generating architecture-native Plain TeX format"
      VERBATIM)
    add_custom_target(plain_format ALL DEPENDS "${_kertex_native_format}")
  endif()
  kertex_tex_engine(virtex "${_kertex_tex_vir_dir}"
    "${KERTEX_SOURCE_DIR}/tex/bin1/virtex/extra.c")
  # The executable name selects Plain TeX in virtex/extra.c.
  kertex_tex_engine(tex "${_kertex_tex_vir_dir}"
    "${KERTEX_SOURCE_DIR}/tex/bin1/virtex/extra.c")

  if(TARGET tex AND TARGET plain_format)
    add_test(NAME plain-tex-smoke
      COMMAND "${CMAKE_COMMAND}"
        -DKERTEX_TEX=$<TARGET_FILE:tex>
        -DKERTEX_RUNTIME_ROOT=${KERTEX_RUNTIME_ROOT}
        -DKERTEX_FORMAT_ROOT=${KERTEX_NATIVE_RUNTIME_ROOT}
        -DKERTEX_TEST_INPUT=${CMAKE_CURRENT_SOURCE_DIR}/cmake/plain-smoke.tex
        -DKERTEX_TEST_DIR=${CMAKE_BINARY_DIR}/tests/plain-tex
        -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/PlainTeXSmoke.cmake")
  endif()
else()
  message(STATUS "Generated WEB sources not found; building source-native utilities only")
endif()

install(DIRECTORY "${KERTEX_SOURCE_DIR}/fonts/" DESTINATION share/kertex/fonts)
if(EXISTS "${KERTEX_RUNTIME_ROOT}")
  install(DIRECTORY "${KERTEX_RUNTIME_ROOT}/" DESTINATION share/kertex
    PATTERN "lib" EXCLUDE)
  if(TARGET plain_format)
    install(FILES "${_kertex_native_format}" DESTINATION bin/lib)
  elseif(EXISTS "${KERTEX_RUNTIME_ROOT}/lib")
    install(DIRECTORY "${KERTEX_RUNTIME_ROOT}/lib/" DESTINATION bin/lib)
  endif()
endif()
