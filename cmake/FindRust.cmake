# Find the Rust toolchain and add the `add_rust_library()` API to build Rust
# libraries.
#
# Copyright (C) 2021-2022 Cisco Systems, Inc. and/or its affiliates. All rights reserved.
#
# Author: Micah Snyder
# To see this in a sample project, visit: https://github.com/micahsnyder/cmake-rust-demo
#
# Code to set the Cargo arguments was lifted from:
# https://github.com/Devolutions/CMakeRust
#
# This Module defines the following variables:
# - <program>_FOUND      - True if the program was found
# - <program>_EXECUTABLE - path of the program
# - <program>_VERSION    - version number of the program
#
# ... for the following Rust toolchain programs:
# - cargo
# - rustc
# - rustup
# - rust-gdb
# - rust-lldb
# - rustdoc
# - rustfmt
# - bindgen
#
# Callers can make any program mandatory by setting `<program>_REQUIRED` before
# the call to `find_package(Rust)`
#
# Eg:
# find_package(Rust REQUIRED)
#
# Callers may set the following variables to control the behavior:
# ================================================================
#
# `CARGO_HOME` - The directory where Cargo should be found.
#                If not set, then it will search in ~/.cargo/bin
#
# `CARGO_CHANNEL` - May be set to `stable`, `beta`, or `nightly`.
#                   If not set, then it attempt to use the stable version.
#
# This module provides the following functions:
# =============================================
#
# `add_rust_library()`
# --------------------
#
# This allows a caller to create a Rust static library
# target which you can link to with `target_link_libraries()`.
#
# Your Rust static library target will itself depend on the native static libs
# you get from `rustc --crate-type staticlib --print=native-static-libs /dev/null`
#
# The CARGO_CMD environment variable will be set to "BUILD" so you can tell
# it's not building the unit tests inside your (optional) `build.rs` file.
#
# Example `add_rust_library()` usage:
#
#   ```cmake
#   add_rust_library(TARGET yourlib
#       SOURCE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
#       BINARY_DIRECTORY "${CMAKE_BINARY_DIR}")
#   add_library(YourProject::yourlib ALIAS yourlib)
#
#   add_executable(yourexe)
#   target_link_libraries(yourexe YourProject::yourlib)
#   ```
#
# If your library has unit tests AND your library does NOT depend on your C
# librar(ies), you can use `add_rust_library()` to build your library and unit
# tests at the same time. Just pass `PRECOMPILE_TESTS TRUE` to add_rust_library.
# This should make it so when you run the tests, they don't have to compile
# during the test run.
#
# If your library does have C dependencies, you can still precompile the tests
# by passing `PRECOMPILE_TESTS TRUE`, with `add_rust_test()` instead.
# It will be slower because it will have to compile the C stuff first,
# then compile the Rust stuff from scratch. See below.
#
# `add_rust_test()`
# -----------------
#
# This allows a caller to run `cargo test` for a specific Rust target as a CTest
# test.
#
# The CARGO_CMD environment variable will be set to "TEST" so you can tell
# it's not building the unit tests inside your (optional) `build.rs` file.
#
# Example `add_rust_test()` usage:
#
#   ```cmake
#   add_rust_test(NAME yourlib
#       SOURCE_DIRECTORY "${CMAKE_SOURCE_DIR}/path/to/yourlib"
#       BINARY_DIRECTORY "${CMAKE_BINARY_DIR}"
#   )
#   set_property(TEST yourlib PROPERTY ENVIRONMENT ${ENVIRONMENT})
#   ```
#
# If your library has unit tests AND your library DOES depend on your C
# libraries, you can precompile the unit tests application with some extra
# parameters to `add_rust_test()`:
# - `PRECOMPILE_TESTS TRUE`
# - `PRECOMPILE_DEPENDS <the CMake target name for your C library dependency>`
# - `PRECOMPILE_ENVIRONMENT <a linked list of environment vars to build the Rust lib>`
#
# The `PRECOMPILE_DEPENDS` option is required so CMake will build the C library first.
# The `PRECOMPILE_ENVIRONMENT` option is required for use in your `build.rs` file so you
# can tell rustc how to link to your C library.
#
# For example:
#
#   ```cmake
#   add_rust_test(NAME yourlib
#       SOURCE_DIRECTORY "${CMAKE_SOURCE_DIR}/yourlib"
#       BINARY_DIRECTORY "${CMAKE_BINARY_DIR}"
#       PRECOMPILE_TESTS TRUE
#       PRECOMPILE_DEPENDS ClamAV::libclamav
#       PRECOMPILE_ENVIRONMENT "${ENVIRONMENT}"
#   )
#   set_property(TEST yourlib PROPERTY ENVIRONMENT ${ENVIRONMENT})
#   ```
#
# `add_rust_executable()`
# -----------------------
#
# This allows a caller to create a Rust executable target.
#
# Example `add_rust_executable()` usage:
#
#   ```cmake
#   add_rust_executable(TARGET yourexe
#       SOURCE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
#       BINARY_DIRECTORY "${CMAKE_BINARY_DIR}"
#   )
#   add_executable(YourProject::yourexe ALIAS yourexe)
#   ```

if(NOT DEFINED CARGO_HOME)
    if(WIN32)
        set(CARGO_HOME "$ENV{USERPROFILE}/.cargo")
    else()
        set(CARGO_HOME "$ENV{HOME}/.cargo")
    endif()
endif()

if(NOT DEFINED CARGO_CHANNEL)
    set(CARGO_CHANNEL "stable")
endif()

include(FindPackageHandleStandardArgs)

function(find_rust_program RUST_PROGRAM)
    find_program(${RUST_PROGRAM}_EXECUTABLE ${RUST_PROGRAM}
        HINTS "${CARGO_HOME}"
        PATH_SUFFIXES "bin"
    )

    if(${RUST_PROGRAM}_EXECUTABLE)
        execute_process(COMMAND "${${RUST_PROGRAM}_EXECUTABLE}" --version
            OUTPUT_VARIABLE ${RUST_PROGRAM}_VERSION_OUTPUT
            ERROR_VARIABLE ${RUST_PROGRAM}_VERSION_ERROR
            RESULT_VARIABLE ${RUST_PROGRAM}_VERSION_RESULT
        )

        if(NOT ${${RUST_PROGRAM}_VERSION_RESULT} EQUAL 0)
            message(STATUS "Rust tool `${RUST_PROGRAM}` not found: Failed to determine version.")
            unset(${RUST_PROGRAM}_EXECUTABLE)
        else()
            string(REGEX
                MATCH "[0-9]+\\.[0-9]+(\\.[0-9]+)?(-nightly)?"
                ${RUST_PROGRAM}_VERSION "${${RUST_PROGRAM}_VERSION_OUTPUT}"
            )
            set(${RUST_PROGRAM}_VERSION "${${RUST_PROGRAM}_VERSION}" PARENT_SCOPE)
            message(STATUS "Rust tool `${RUST_PROGRAM}` found: ${${RUST_PROGRAM}_EXECUTABLE}, ${${RUST_PROGRAM}_VERSION}")
        endif()

        mark_as_advanced(${RUST_PROGRAM}_EXECUTABLE ${RUST_PROGRAM}_VERSION)
    else()
        if(${${RUST_PROGRAM}_REQUIRED})
            message(FATAL_ERROR "Rust tool `${RUST_PROGRAM}` not found.")
        else()
            message(STATUS "Rust tool `${RUST_PROGRAM}` not found.")
        endif()
    endif()
endfunction()

function(cargo_vendor)
    set(options)
    set(oneValueArgs TARGET SOURCE_DIRECTORY BINARY_DIRECTORY)
    cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT EXISTS ${ARGS_SOURCE_DIRECTORY}/.cargo/config.toml)
        # Vendor the dependencies and create .cargo/config.toml
        # Vendored dependencies will be used during the build.
        # This will allow us to package vendored dependencies in source tarballs
        # for online builds when we run `cpack --config CPackSourceConfig.cmake`
        message(STATUS "Running `cargo vendor` to collect dependencies for ${ARGS_TARGET}. This may take a while if the local crates.io index needs to be updated ...")
        make_directory(${ARGS_SOURCE_DIRECTORY}/.cargo)
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E env "CARGO_TARGET_DIR=${ARGS_BINARY_DIRECTORY}" ${cargo_EXECUTABLE} vendor ".cargo/vendor"
            WORKING_DIRECTORY "${ARGS_SOURCE_DIRECTORY}"
            OUTPUT_VARIABLE CARGO_VENDOR_OUTPUT
            ERROR_VARIABLE CARGO_VENDOR_ERROR
            RESULT_VARIABLE CARGO_VENDOR_RESULT
        )

        if(NOT ${CARGO_VENDOR_RESULT} EQUAL 0)
            message(FATAL_ERROR "Failed!\n${CARGO_VENDOR_ERROR}")
        else()
            message("Success!")
        endif()

        write_file(${ARGS_SOURCE_DIRECTORY}/.cargo/config.toml "
[source.crates-io]
replace-with = \"vendored-sources\"

[source.vendored-sources]
directory = \".cargo/vendor\"
"
        )
    endif()
endfunction()

function(add_rust_executable)
    set(options)
    set(oneValueArgs TARGET SOURCE_DIRECTORY BINARY_DIRECTORY)
    cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(WIN32)
        set(OUTPUT "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/${CARGO_BUILD_TYPE}/${ARGS_TARGET}.exe")
    else()
        set(OUTPUT "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/${CARGO_BUILD_TYPE}/${ARGS_TARGET}")
    endif()

    file(GLOB_RECURSE EXE_SOURCES "${ARGS_SOURCE_DIRECTORY}/*.rs")

    set(MY_CARGO_ARGS ${CARGO_ARGS})
    list(APPEND MY_CARGO_ARGS "--target-dir" ${ARGS_BINARY_DIRECTORY})
    list(JOIN MY_CARGO_ARGS " " MY_CARGO_ARGS_STRING)

    # Build the executable.
    add_custom_command(
        OUTPUT "${OUTPUT}"
        COMMAND ${CMAKE_COMMAND} -E env "CARGO_TARGET_DIR=${ARGS_BINARY_DIRECTORY}" ${cargo_EXECUTABLE} ARGS ${MY_CARGO_ARGS}
        WORKING_DIRECTORY "${ARGS_SOURCE_DIRECTORY}"
        DEPENDS ${EXE_SOURCES}
        COMMENT "Building ${ARGS_TARGET} in ${ARGS_BINARY_DIRECTORY} with:\n\t ${cargo_EXECUTABLE} ${MY_CARGO_ARGS_STRING}")

    # Create a target from the build output
    add_custom_target(${ARGS_TARGET}_target
        DEPENDS ${OUTPUT})

    # Create an executable target from custom target
    add_custom_target(${ARGS_TARGET} ALL DEPENDS ${ARGS_TARGET}_target)

    # Specify where the executable is
    set_target_properties(${ARGS_TARGET}
        PROPERTIES
        IMPORTED_LOCATION "${OUTPUT}"
    )

    # Vendor the dependencies, if desired
    if(VENDOR_DEPENDENCIES)
        cargo_vendor(TARGET "${ARGS_TARGET}"
            SOURCE_DIRECTORY "${ARGS_SOURCE_DIRECTORY}"
            BINARY_DIRECTORY "${ARGS_BINARY_DIRECTORY}"
        )
    endif()
endfunction()

function(add_rust_library)
    set(options)
    set(oneValueArgs TARGET SOURCE_DIRECTORY BINARY_DIRECTORY PRECOMPILE_TESTS)
    cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(WIN32)
        set(OUTPUT "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/${CARGO_BUILD_TYPE}/${ARGS_TARGET}.lib")
    else()
        set(OUTPUT "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/${CARGO_BUILD_TYPE}/lib${ARGS_TARGET}.a")
    endif()

    file(GLOB_RECURSE LIB_SOURCES "${ARGS_SOURCE_DIRECTORY}/*.rs")

    set(MY_CARGO_ARGS ${CARGO_ARGS})
    if(ARGS_PRECOMPILE_TESTS)
        list(APPEND MY_CARGO_ARGS "--tests")
    endif()
    list(APPEND MY_CARGO_ARGS "--target-dir" ${ARGS_BINARY_DIRECTORY})
    list(JOIN MY_CARGO_ARGS " " MY_CARGO_ARGS_STRING)

    # Build the library and generate the c-binding
    if("${CMAKE_OSX_ARCHITECTURES}" MATCHES "^(arm64;x86_64|x86_64;arm64)$")
        add_custom_command(
            OUTPUT "${OUTPUT}"
            COMMAND ${CMAKE_COMMAND} -E env "CARGO_CMD=build" "CARGO_TARGET_DIR=${ARGS_BINARY_DIRECTORY}" "MAINTAINER_MODE=${MAINTAINER_MODE}" "RUSTFLAGS=\"${RUSTFLAGS}\"" ${cargo_EXECUTABLE} ARGS ${MY_CARGO_ARGS} --target=x86_64-apple-darwin
            COMMAND ${CMAKE_COMMAND} -E env "CARGO_CMD=build" "CARGO_TARGET_DIR=${ARGS_BINARY_DIRECTORY}" "MAINTAINER_MODE=${MAINTAINER_MODE}" "RUSTFLAGS=\"${RUSTFLAGS}\"" ${cargo_EXECUTABLE} ARGS ${MY_CARGO_ARGS} --target=aarch64-apple-darwin
            COMMAND ${CMAKE_COMMAND} -E make_directory "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/${CARGO_BUILD_TYPE}"
            COMMAND lipo ARGS -create ${ARGS_BINARY_DIRECTORY}/x86_64-apple-darwin/${CARGO_BUILD_TYPE}/lib${ARGS_TARGET}.a ${ARGS_BINARY_DIRECTORY}/aarch64-apple-darwin/${CARGO_BUILD_TYPE}/lib${ARGS_TARGET}.a -output "${OUTPUT}"
            WORKING_DIRECTORY "${ARGS_SOURCE_DIRECTORY}"
            DEPENDS ${LIB_SOURCES}
            COMMENT "Building ${ARGS_TARGET} in ${ARGS_BINARY_DIRECTORY} with:  ${cargo_EXECUTABLE} ${MY_CARGO_ARGS_STRING}")
    else()
        add_custom_command(
            OUTPUT "${OUTPUT}"
            COMMAND ${CMAKE_COMMAND} -E env "CARGO_CMD=build" "CARGO_TARGET_DIR=${ARGS_BINARY_DIRECTORY}" "MAINTAINER_MODE=${MAINTAINER_MODE}" "RUSTFLAGS=\"${RUSTFLAGS}\"" ${cargo_EXECUTABLE} ARGS ${MY_CARGO_ARGS}
            WORKING_DIRECTORY "${ARGS_SOURCE_DIRECTORY}"
            DEPENDS ${LIB_SOURCES}
            COMMENT "Building ${ARGS_TARGET} in ${ARGS_BINARY_DIRECTORY} with:  ${cargo_EXECUTABLE} ${MY_CARGO_ARGS_STRING}")
    endif()

    # Create a target from the build output
    add_custom_target(${ARGS_TARGET}_target
        DEPENDS ${OUTPUT})

    # Create a static imported library target from custom target
    add_library(${ARGS_TARGET} STATIC IMPORTED GLOBAL)
    add_dependencies(${ARGS_TARGET} ${ARGS_TARGET}_target)
    target_link_libraries(${ARGS_TARGET} INTERFACE ${RUST_NATIVE_STATIC_LIBS})

    # Specify where the library is and where to find the headers
    set_target_properties(${ARGS_TARGET}
        PROPERTIES
        IMPORTED_LOCATION "${OUTPUT}"
        INTERFACE_INCLUDE_DIRECTORIES "${ARGS_SOURCE_DIRECTORY};${ARGS_BINARY_DIRECTORY}"
    )

    # Vendor the dependencies, if desired
    if(VENDOR_DEPENDENCIES)
        cargo_vendor(TARGET "${ARGS_TARGET}"
            SOURCE_DIRECTORY "${ARGS_SOURCE_DIRECTORY}"
            BINARY_DIRECTORY "${ARGS_BINARY_DIRECTORY}")
    endif()
endfunction()

function(add_rust_test)
    set(options)
    set(oneValueArgs NAME SOURCE_DIRECTORY BINARY_DIRECTORY PRECOMPILE_TESTS PRECOMPILE_DEPENDS)
    set(multiValueArgs PRECOMPILE_ENVIRONMENT)
    cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(MY_CARGO_ARGS "test")

    if(NOT DEFINED _RUSTUP_TOOLCHAIN_FULL)
        if(NOT "${CMAKE_OSX_ARCHITECTURES}" MATCHES "^(arm64;x86_64|x86_64;arm64)$") # Don't specify the target for universal, we'll do that manually for each build.
            list(APPEND MY_CARGO_ARGS "--target" ${RUST_COMPILER_TARGET})
        endif()
    endif()

    if("${CMAKE_BUILD_TYPE}" STREQUAL "Release")
        list(APPEND MY_CARGO_ARGS "--release")
    endif()

    list(APPEND MY_CARGO_ARGS "--target-dir" ${ARGS_BINARY_DIRECTORY})
    list(JOIN MY_CARGO_ARGS " " MY_CARGO_ARGS_STRING)

    if(ARGS_PRECOMPILE_TESTS)
        list(APPEND ARGS_PRECOMPILE_ENVIRONMENT "CARGO_CMD=test" "CARGO_TARGET_DIR=${ARGS_BINARY_DIRECTORY}")
        add_custom_target(${ARGS_NAME}_tests ALL
            COMMAND ${CMAKE_COMMAND} -E env ${ARGS_PRECOMPILE_ENVIRONMENT} ${cargo_EXECUTABLE} ${MY_CARGO_ARGS} --color always --no-run
            DEPENDS ${ARGS_PRECOMPILE_DEPENDS}
            WORKING_DIRECTORY ${ARGS_SOURCE_DIRECTORY}
        )
    endif()

    add_test(
        NAME ${ARGS_NAME}
        COMMAND ${CMAKE_COMMAND} -E env "CARGO_CMD=test" "CARGO_TARGET_DIR=${ARGS_BINARY_DIRECTORY}" ${cargo_EXECUTABLE} ${MY_CARGO_ARGS} --color always
        WORKING_DIRECTORY ${ARGS_SOURCE_DIRECTORY}
    )
endfunction()

#
# Find Rustup first.
# If found, we may use it in combination with the CARGO_CHANNEL option to determine the toolchain and use those toolchain binaries directly.
#
find_rust_program(rustup)

if(NOT RUST_COMPILER_TARGET)
    # Automatically determine the Rust Target Triple.
    # Note: Users may override automatic target detection by specifying their own. Most likely needed for cross-compiling.
    # For reference determining target platform: https://doc.rust-lang.org/nightly/rustc/platform-support.html
    if(WIN32)
        # For windows x86/x64, it's easy enough to guess the target.
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(RUST_COMPILER_TARGET "x86_64-pc-windows-msvc")
        else()
            set(RUST_COMPILER_TARGET "i686-pc-windows-msvc")
        endif()
    elseif(CMAKE_SYSTEM_NAME STREQUAL Darwin AND "${CMAKE_OSX_ARCHITECTURES}" MATCHES "^(arm64;x86_64|x86_64;arm64)$")
        # Special case for Darwin because we may want to build universal binaries.
        set(RUST_COMPILER_TARGET "universal-apple-darwin")
    endif()
endif()

if(DEFINED rustup_EXECUTABLE AND NOT RUST_COMPILER_TARGET STREQUAL "universal-apple-darwin")
    # Use rustup to identify the path of the real cargo bin directory.
    # This way we don't use the rustup shims that get confused when run as a different user that doesn't have cargo installed..

    # Much of this logic courtesy of the Corrosion project:
    # https://github.com/corrosion-rs/corrosion/blob/master/cmake/FindRust.cmake#L86
    execute_process(
        COMMAND ${rustup_EXECUTABLE} toolchain list --verbose
        OUTPUT_VARIABLE _TOOLCHAINS_RAW
    )

    string(REPLACE "\n" ";" _TOOLCHAINS_RAW "${_TOOLCHAINS_RAW}")

    foreach(_TOOLCHAIN_RAW ${_TOOLCHAINS_RAW})
        if(_TOOLCHAIN_RAW MATCHES "([a-zA-Z0-9\\._\\-]+)[ \t\r\n]?(\\(default\\) \\(override\\)|\\(default\\)|\\(override\\))?[ \t\r\n]+(.+)")
            set(_TOOLCHAIN "${CMAKE_MATCH_1}")
            set(_TOOLCHAIN_TYPE ${CMAKE_MATCH_2})
            list(APPEND _DISCOVERED_TOOLCHAINS ${_TOOLCHAIN})

            set(${_TOOLCHAIN}_PATH "${CMAKE_MATCH_3}")

            if(_TOOLCHAIN_TYPE MATCHES ".*\\(default\\).*")
                set(_TOOLCHAIN_DEFAULT ${_TOOLCHAIN})
            endif()

            if(_TOOLCHAIN_TYPE MATCHES ".*\\(override\\).*")
                set(_TOOLCHAIN_OVERRIDE ${_TOOLCHAIN})
            endif()
        else()
            message(WARNING "Didn't recognize toolchain: ${_TOOLCHAIN_RAW}")
        endif()
    endforeach()

    if(RUST_COMPILER_TARGET)
        # The caller has requested a specific compiler target.  Try to use it.
        if("${CARGO_CHANNEL}-${RUST_COMPILER_TARGET}" IN_LIST _DISCOVERED_TOOLCHAINS)
            set(_TOOLCHAIN_SELECTED ${CARGO_CHANNEL}-${RUST_COMPILER_TARGET})
        else()
            message(FATAL_ERROR "RUST_COMPILER_TARGET is set to ${RUST_COMPILER_TARGET}, but no toolchain for that target is installed.  Available toolchains: ${_DISCOVERED_TOOLCHAINS}")
        endif()
    else()
        # Use the default or the override toolchain, if overridden.
        if(NOT DEFINED Rust_TOOLCHAIN)
            if(NOT DEFINED _TOOLCHAIN_OVERRIDE)
                set(_TOOLCHAIN_SELECTED ${_TOOLCHAIN_DEFAULT})
            else()
                set(_TOOLCHAIN_SELECTED ${_TOOLCHAIN_OVERRIDE})
            endif()
        endif()
    endif()

    set(Rust_TOOLCHAIN ${_TOOLCHAIN_SELECTED} CACHE STRING "The rustup toolchain to use")
    message(STATUS "Rust Toolchain: ${Rust_TOOLCHAIN}")

    if(NOT Rust_TOOLCHAIN IN_LIST _DISCOVERED_TOOLCHAINS)
        # If the precise toolchain wasn't found, try appending the default host
        execute_process(
            COMMAND ${Rust_RUSTUP} show
            OUTPUT_VARIABLE _SHOW_RAW
        )

        if(_SHOW_RAW MATCHES "Default host: ([a-zA-Z0-9_\\-]*)\n")
            set(_DEFAULT_HOST "${CMAKE_MATCH_1}")
        else()
            message(FATAL_ERROR "Failed to parse \"Default host\" from `${Rust_RUSTUP} show`. Got: ${_SHOW_RAW}")
        endif()

        if(NOT "${Rust_TOOLCHAIN}-${_DEFAULT_HOST}" IN_LIST _DISCOVERED_TOOLCHAINS)
            message(NOTICE "Could not find toolchain '${Rust_TOOLCHAIN}'")
            message(NOTICE "Available toolchains:")

            list(APPEND CMAKE_MESSAGE_INDENT "  ")

            foreach(_TOOLCHAIN ${_DISCOVERED_TOOLCHAINS})
                message(NOTICE "${_TOOLCHAIN}")
            endforeach()

            list(POP_BACK CMAKE_MESSAGE_INDENT)

            message(FATAL_ERROR "")
        endif()

        set(_RUSTUP_TOOLCHAIN_FULL "${Rust_TOOLCHAIN}-${_DEFAULT_HOST}")
    else()
        set(_RUSTUP_TOOLCHAIN_FULL "${Rust_TOOLCHAIN}")
    endif()

    set(CARGO_HOME "${${_RUSTUP_TOOLCHAIN_FULL}_PATH}")
    message(VERBOSE "Rust toolchain ${_RUSTUP_TOOLCHAIN_FULL}")
    message(VERBOSE "Rust toolchain path ${CARGO_HOME}")
endif()

#
# Cargo is the primary tool for using the Rust Toolchain to to build static
# libs that can include other crate dependencies.
#
find_rust_program(cargo)

# Rustc will be required to determine the target triple.
find_rust_program(rustc)

if(NOT RUST_COMPILER_TARGET)
    # Determine LLVM target triple.
    execute_process(COMMAND ${rustc_EXECUTABLE} -vV
        OUTPUT_VARIABLE RUSTC_VV_OUT ERROR_QUIET)
    string(REGEX REPLACE "^.*host: ([a-zA-Z0-9_\\-]+).*" "\\1" RUST_COMPILER_TARGET1 "${RUSTC_VV_OUT}")
    string(STRIP ${RUST_COMPILER_TARGET1} RUST_COMPILER_TARGET)
endif()

# These other programs may also be useful...
find_rust_program(rust-gdb)
find_rust_program(rust-lldb)
find_rust_program(rustdoc)
find_rust_program(rustfmt)
find_rust_program(bindgen)

if(RUSTC_MINIMUM_REQUIRED AND rustc_VERSION VERSION_LESS RUSTC_MINIMUM_REQUIRED)
    message(FATAL_ERROR "Your Rust toolchain is to old to build this project:
    ${rustc_VERSION} < ${RUSTC_MINIMUM_REQUIRED}")
endif()

# Determine the native libs required to link w/ rust static libs
# message(STATUS "Detecting native static libs for rust: ${rustc_EXECUTABLE} --crate-type staticlib --print=native-static-libs /dev/null")
execute_process(
    COMMAND ${CMAKE_COMMAND} -E env "CARGO_TARGET_DIR=${CMAKE_BINARY_DIR}" ${rustc_EXECUTABLE} --crate-type staticlib --print=native-static-libs /dev/null
    OUTPUT_VARIABLE RUST_NATIVE_STATIC_LIBS_OUTPUT
    ERROR_VARIABLE RUST_NATIVE_STATIC_LIBS_ERROR
    RESULT_VARIABLE RUST_NATIVE_STATIC_LIBS_RESULT
)
string(REGEX REPLACE "\r?\n" ";" LINE_LIST "${RUST_NATIVE_STATIC_LIBS_ERROR}")

foreach(LINE ${LINE_LIST})
    # do the match on each line
    string(REGEX MATCH "native-static-libs: .*" LINE "${LINE}")

    if(NOT LINE)
        continue()
    endif()

    string(REPLACE "native-static-libs: " "" LINE "${LINE}")
    string(REGEX REPLACE "  " "" LINE "${LINE}")
    string(REGEX REPLACE " " ";" LINE "${LINE}")

    if(LINE)
        message(STATUS "Rust's native static libs: ${LINE}")
        set(RUST_NATIVE_STATIC_LIBS "${LINE}")
        break()
    endif()
endforeach()

set(CARGO_ARGS "build")

if(NOT DEFINED _RUSTUP_TOOLCHAIN_FULL)
    if(NOT "${RUST_COMPILER_TARGET}" MATCHES "^universal-apple-darwin$")
        # Don't specify the target for macOS universal builds, we'll do that manually for each build.
        list(APPEND CARGO_ARGS "--target" ${RUST_COMPILER_TARGET})
    endif()
endif()

set(RUSTFLAGS "")

if(NOT CMAKE_BUILD_TYPE)
    set(CARGO_BUILD_TYPE "debug")
elseif(${CMAKE_BUILD_TYPE} STREQUAL "Release" OR ${CMAKE_BUILD_TYPE} STREQUAL "MinSizeRel")
    set(CARGO_BUILD_TYPE "release")
    list(APPEND CARGO_ARGS "--release")
elseif(${CMAKE_BUILD_TYPE} STREQUAL "RelWithDebInfo")
    set(CARGO_BUILD_TYPE "release")
    list(APPEND CARGO_ARGS "--release")
    set(RUSTFLAGS "-g")
else()
    set(CARGO_BUILD_TYPE "debug")
endif()

find_package_handle_standard_args(Rust
    REQUIRED_VARS cargo_EXECUTABLE
    VERSION_VAR cargo_VERSION
)
