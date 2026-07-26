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

message(STATUS "kerTeX target: ${KERTEX_ARCH}")
message(STATUS "TinyCC package: ${KERTEX_TCC_ROOT}")
message(STATUS "WCRT package: ${KERTEX_WCRT_ROOT}")

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/include")
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/cmake/kertex.h.in" "${CMAKE_BINARY_DIR}/include/kertex.h" @ONLY)
include_directories(BEFORE "${KERTEX_WCRT_ROOT}/include")
include_directories(BEFORE "${CMAKE_BINARY_DIR}/include")
include_directories("${KERTEX_SOURCE_DIR}/lib1/pascal")

add_library(kertex_wcrt INTERFACE)
target_link_options(kertex_wcrt INTERFACE -nostdlib "${KERTEX_TCC_ROOT}/lib/kernel32.def")
target_link_libraries(kertex_wcrt INTERFACE "${KERTEX_WCRT_ROOT}/lib/libwcrt.a")
if(KERTEX_ARCH STREQUAL "x86")
  target_compile_definitions(kertex_wcrt INTERFACE WINVER=0x0500 _WIN32_WINNT=0x0500)
  target_link_libraries(kertex_wcrt INTERFACE "${KERTEX_TCC_ROOT}/lib/i386-win32-libtcc1.a")
elseif(KERTEX_ARCH STREQUAL "x64")
  target_link_libraries(kertex_wcrt INTERFACE "${KERTEX_TCC_ROOT}/lib/x86_64-win32-libtcc1.a")
else()
  target_link_libraries(kertex_wcrt INTERFACE "${KERTEX_TCC_ROOT}/lib/arm64-win32-libtcc1.a")
endif()

function(kertex_program name)
  add_executable(${name} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/wcrt_start.c" ${ARGN})
  set_property(TARGET ${name} PROPERTY C_STANDARD 90)
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
      kertex_program(${name} "${_source}")
      target_include_directories(${name} PRIVATE
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
  kertex_generated_program(mft mfware/bin1/mft)
  kertex_generated_program(tftopl texware/bin1/tftopl)
  kertex_generated_program(pltotf texware/bin1/pltotf)
  kertex_generated_program(bibtex texware/bin1/bibtex)
  kertex_generated_program(dvitype dviware/bin1/dvitype)
  kertex_generated_program(vftovp fontware/bin1/vftovp)
  kertex_generated_program(vptovf fontware/bin1/vptovf)
  kertex_generated_program(gftopk fontware/bin1/gftopk)
  kertex_generated_program(dvitomp mpware/bin1/dvitomp)
else()
  message(STATUS "Generated WEB sources not found; building source-native utilities only")
endif()

install(DIRECTORY "${KERTEX_SOURCE_DIR}/fonts/" DESTINATION share/kertex/fonts)
