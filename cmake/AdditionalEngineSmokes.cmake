function(run_engine_smoke name executable pool dump instruction)
  set(_test_dir "${KERTEX_TEST_ROOT}/${name}")
  file(REMOVE_RECURSE "${_test_dir}")
  file(MAKE_DIRECTORY "${_test_dir}")
  get_filename_component(_pool_name "${pool}" NAME)
  file(COPY_FILE "${pool}" "${_test_dir}/${_pool_name}")
  if(NOT "${dump}" STREQUAL "")
    get_filename_component(_dump_name "${dump}" NAME)
    file(COPY_FILE "${dump}" "${_test_dir}/${_dump_name}")
  endif()

  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
      "KERTEX_LIBDIR=." "KERTEX_BINDIR=." "KERTEXPOOL=."
      "KERTEXINPUTS=." "KERTEXDUMP=."
      "${executable}" ${ARGN} "${instruction}"
    WORKING_DIRECTORY "${_test_dir}"
    RESULT_VARIABLE _result
    OUTPUT_VARIABLE _stdout
    ERROR_VARIABLE _stderr)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR
      "${name} smoke test failed (${_result})\n${_stdout}\n${_stderr}")
  endif()
endfunction()

run_engine_smoke(metafont "${KERTEX_VIRMF}"
  "${KERTEX_RUNTIME_ROOT}/pool/mf.pool"
  "${KERTEX_FORMAT_ROOT}/lib/plain.base"
  "\\relax; end" "&plain")
run_engine_smoke(metapost "${KERTEX_VIRMP}"
  "${KERTEX_RUNTIME_ROOT}/pool/mp.pool"
  "${KERTEX_FORMAT_ROOT}/lib/plain.mem"
  "\\relax; end" "&plain")
run_engine_smoke(etex "${KERTEX_EINITEX}"
  "${KERTEX_RUNTIME_ROOT}/pool/etex.pool" "" "\\end")
run_engine_smoke(prote "${KERTEX_INIPROTE}"
  "${KERTEX_RUNTIME_ROOT}/pool/prote.pool" "" "\\end")
