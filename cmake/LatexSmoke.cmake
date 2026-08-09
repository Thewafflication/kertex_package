file(REMOVE_RECURSE "${KERTEX_TEST_DIR}")
file(MAKE_DIRECTORY "${KERTEX_TEST_DIR}")
get_filename_component(_input_name "${KERTEX_TEST_INPUT}" NAME)
file(COPY_FILE "${KERTEX_TEST_INPUT}" "${KERTEX_TEST_DIR}/${_input_name}")

set(_environment
  "FORCE_SOURCE_DATE=1" "SOURCE_DATE_EPOCH=D:20260101000000Z"
  "KERTEX_LIBDIR=${KERTEX_RUNTIME_ROOT}"
  "KERTEX_BINDIR=${KERTEX_FORMAT_ROOT}"
  "KERTEXDUMP=${KERTEX_FORMAT_ROOT}/lib")

foreach(_pass RANGE 1 3)
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env ${_environment}
      "${KERTEX_LATEX}" "${_input_name}"
    WORKING_DIRECTORY "${KERTEX_TEST_DIR}"
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr
    TIMEOUT 120)
  if(NOT _result EQUAL 0)
    set(_log "")
    if(EXISTS "${KERTEX_TEST_DIR}/latex-smoke.log")
      file(READ "${KERTEX_TEST_DIR}/latex-smoke.log" _log)
    endif()
    message(FATAL_ERROR
      "LaTeX pass ${_pass} failed (${_result})\n${_stdout}\n${_stderr}\n${_log}")
  endif()
endforeach()

set(_dvi "${KERTEX_TEST_DIR}/latex-smoke.dvi")
set(_log_path "${KERTEX_TEST_DIR}/latex-smoke.log")
if(NOT EXISTS "${_dvi}" OR NOT EXISTS "${_log_path}")
  message(FATAL_ERROR "LaTeX did not produce its DVI and transcript")
endif()
file(SIZE "${_dvi}" _dvi_size)
if(_dvi_size LESS 1024)
  message(FATAL_ERROR "LaTeX produced an invalid ${_dvi_size}-byte DVI")
endif()
file(READ "${_log_path}" _log)
foreach(_fatal_pattern
    "(^|\n)! " "Undefined control sequence" "LaTeX Error:"
    "Metric \\(TFM\\) file not found" "File .* not found" "not loadable"
    "Missing character:" "undefined references"
    "Label\\(s\\) may have changed" "Rerun to get" "MiKTeX" "texlive"
    "texmf-dist")
  if(_log MATCHES "${_fatal_pattern}")
    message(FATAL_ERROR "Final LaTeX transcript contains '${_fatal_pattern}':\n${_log}")
  endif()
endforeach()

file(WRITE "${KERTEX_TEST_DIR}/dvitype.in" "0\n*\n1000000\n300/1\n0\n")
execute_process(
  COMMAND "${CMAKE_COMMAND}" -E env ${_environment}
    "${KERTEX_DVITYPE}" "${_dvi}"
  INPUT_FILE "${KERTEX_TEST_DIR}/dvitype.in"
  WORKING_DIRECTORY "${KERTEX_TEST_DIR}"
  RESULT_VARIABLE _dvitype_result
  OUTPUT_VARIABLE _dvitype_stdout ERROR_VARIABLE _dvitype_stderr
  TIMEOUT 120)
if(NOT _dvitype_result EQUAL 0)
  message(FATAL_ERROR
    "dvitype rejected the LaTeX DVI (${_dvitype_result})"
    "\n${_dvitype_stdout}\n${_dvitype_stderr}")
endif()
