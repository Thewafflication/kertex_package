file(MAKE_DIRECTORY "${KERTEX_TEST_DIR}")
file(REMOVE
  "${KERTEX_TEST_DIR}/plain-smoke.dvi"
  "${KERTEX_TEST_DIR}/plain-smoke.log")
execute_process(
  COMMAND "${CMAKE_COMMAND}" -E env
    "KERTEX_LIBDIR=${KERTEX_RUNTIME_ROOT}"
    "KERTEX_BINDIR=${KERTEX_RUNTIME_ROOT}"
    "KERTEXFONTS=${KERTEX_RUNTIME_ROOT}/fonts/tfm"
    "${KERTEX_TEX}" "${KERTEX_TEST_INPUT}"
  WORKING_DIRECTORY "${KERTEX_TEST_DIR}"
  RESULT_VARIABLE _result
  OUTPUT_VARIABLE _stdout
  ERROR_VARIABLE _stderr)
if(NOT _result EQUAL 0 OR NOT EXISTS "${KERTEX_TEST_DIR}/plain-smoke.dvi")
  message(FATAL_ERROR
    "Plain TeX smoke test failed (${_result})\n${_stdout}\n${_stderr}")
endif()
