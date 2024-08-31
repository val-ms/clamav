# Platform
set(CMAKE_SYSTEM_NAME       Windows)
set(CMAKE_SYSTEM_PROCESSOR  arm64)
set(RUST_COMPILER_TARGET    "aarch64-pc-windows-msvc")

# Project Variables needed to cross compile
set(HAVE_PRAGMA_PACK        1)
set(HAVE_SAR                1)
set(MMAP_FOR_CROSSCOMPILING OFF)
set(ENABLE_SYSTEMD          OFF)

set( test_run_result
     "PLEASE_FILL_OUT-FAILED_TO_RUN"
     CACHE STRING "Result from try_run" FORCE)

set( test_run_result__TRYRUN_OUTPUT
     "PLEASE_FILL_OUT-NOTFOUND"
     CACHE STRING "Output from try_run" FORCE)