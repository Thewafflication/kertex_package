file(MAKE_DIRECTORY "${KERTEX_TEST_DIR}")
file(RELATIVE_PATH _kertex_runtime_root
  "${KERTEX_TEST_DIR}" "${KERTEX_RUNTIME_ROOT}")
set(_kertex_runtime_root "./${_kertex_runtime_root}")
file(REMOVE
  "${KERTEX_TEST_DIR}/plain-smoke.dvi"
  "${KERTEX_TEST_DIR}/plain-smoke.log")
get_filename_component(_kertex_test_input_name "${KERTEX_TEST_INPUT}" NAME)
file(COPY_FILE
  "${KERTEX_TEST_INPUT}"
  "${KERTEX_TEST_DIR}/${_kertex_test_input_name}"
  ONLY_IF_DIFFERENT)
execute_process(
  COMMAND "${CMAKE_COMMAND}" -E env
    "KERTEX_LIBDIR=${_kertex_runtime_root}"
    "KERTEX_BINDIR=${_kertex_runtime_root}"
    "KERTEXPOOL=${_kertex_runtime_root}/pool"
    "KERTEXDUMP=${_kertex_runtime_root}/lib"
    "KERTEXFONTS=${_kertex_runtime_root}/fonts/tfm"
    "${KERTEX_INITEX}" "\\end"
  WORKING_DIRECTORY "${KERTEX_TEST_DIR}"
  RESULT_VARIABLE _initex_result
  OUTPUT_VARIABLE _initex_stdout
  ERROR_VARIABLE _initex_stderr)
if(NOT _initex_result EQUAL 0)
  message(FATAL_ERROR
    "Initial TeX startup probe failed (${_initex_result})"
    "\n${_initex_stdout}\n${_initex_stderr}")
endif()
execute_process(
  COMMAND "${CMAKE_COMMAND}" -E env
    "KERTEX_LIBDIR=${_kertex_runtime_root}"
    "KERTEX_BINDIR=${_kertex_runtime_root}"
    "KERTEXPOOL=${_kertex_runtime_root}/pool"
    "KERTEXDUMP=${_kertex_runtime_root}/lib"
    "KERTEXFONTS=${_kertex_runtime_root}/fonts/tfm"
    "${KERTEX_TEX}" "&plain" "${_kertex_test_input_name}"
  WORKING_DIRECTORY "${KERTEX_TEST_DIR}"
  RESULT_VARIABLE _result
  OUTPUT_VARIABLE _stdout
  ERROR_VARIABLE _stderr)
if(NOT _result EQUAL 0 OR NOT EXISTS "${KERTEX_TEST_DIR}/plain-smoke.dvi")
  set(_log "")
  if(EXISTS "${KERTEX_TEST_DIR}/plain-smoke.log")
    file(READ "${KERTEX_TEST_DIR}/plain-smoke.log" _log)
  endif()
  message(FATAL_ERROR
    "Plain TeX smoke test failed (${_result})\n${_stdout}\n${_stderr}"
    "\nTeX transcript:\n${_log}")
endif()
