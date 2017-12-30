#*********************************************************#
#*  File: AndroidApk.cmake                                *
#*    Android apk tools
#*
#*  Copyright (C) 2002-2013 The PixelLight Team (http://www.pixellight.org/)
#*  Copyright (C) 2015-2016 Ruslan Baratov
#*  Copyright (C) 2015 David Hirvonen
#*
#*  This file is part of PixelLight.
#*
#*  Permission is hereby granted, free of charge, to any person obtaining a
#*  copy of this software and associated documentation files (the "Software"),
#*  to deal in the Software without restriction, including without limitation
#*  the rights to use, copy, modify, merge, publish, distribute, sublicense,
#*  and/or sell copies of the Software, and to permit persons to whom the
#*  Software is furnished to do so, subject to the following conditions:
#*
#*  The above copyright notice and this permission notice shall be included
#*  in all copies or substantial portions of the Software.
#*
#*  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#*  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#*  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#*  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#*  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#*  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
#*  DEALINGS IN THE SOFTWARE.
#*********************************************************#

include(CMakeParseArguments) # cmake_parse_arguments

# Directory this CMake file is in
set(_ANDROID_APK_THIS_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")

##################################################
## FUNCTION: apk_check_not_empty
##
## Check that variable and it's value is not an empty string
##################################################

function(apk_check_not_empty varname)
  string(COMPARE EQUAL "${varname}" "" is_empty)
  if(is_empty)
    message(FATAL_ERROR "Incorrect usage: `varname` is empty")
  endif()

  string(COMPARE EQUAL "${${varname}}" "" is_empty)
  if(is_empty)
    message(FATAL_ERROR "Variable `${varname}` is empty")
  endif()
endfunction()

##################################################
## FUNCTION: apk_find_tool
##
## Find required tools
##################################################

function(apk_find_tool toolname result)
  apk_check_not_empty(toolname)
  apk_check_not_empty(result)

  if(EXISTS "${toolname}")
    set("${result}" "${toolname}" PARENT_SCOPE)
    return()
  endif()

  find_host_program("${result}" "${toolname}")
  if(EXISTS "${${result}}")
    set("${result}" "${${result}}" PARENT_SCOPE)
  else()
    message(FATAL_ERROR "Tool not found in PATH: ${toolname}")
  endif()
endfunction()

##################################################
## FUNCTION: android_copy_files
##
## Copy files from one place to another using wildcards
##################################################
function(android_copy_files targetname src dst)
  apk_check_not_empty(targetname)
  apk_check_not_empty(src)
  apk_check_not_empty(dst)

  if(NOT TARGET "${targetname}")
    message(FATAL_ERROR "Not a target: ${targetname}")
  endif()

  # Get path
  get_filename_component(path "${src}" PATH)

  # Find files
  file(GLOB_RECURSE files RELATIVE "${path}" "${src}")

  list(LENGTH files number_of_files)
  if(number_of_files EQUAL "0")
    message(
        FATAL_ERROR
        "Not files found by pattern '${path}'. Wildcard is missing?"
        " Pattern example: '/home/user/myassets/*'"
    )
  endif()

  # Find files
  foreach(file ${files})
    # Get source and destination file
    set(src_file "${path}/${file}")
    set(dst_file "${dst}/${file}")

    # Create output directory
    get_filename_component(dst_path "${dst_file}" PATH)
    file(MAKE_DIRECTORY "${dst_path}")

    # Copy file
    add_custom_command(
        TARGET "${targetname}" POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy "${src_file}" "${dst_file}" VERBATIM
    )
  endforeach()
endfunction()

##################################################
## FUNCTION: android_create_apk
##
## Create/copy Android apk related files
##
## @param BASE_TARGET
##   Library target that will be used for creating apk
## @param APK_TARGET
##   Name of the target for creating apk
## @param INSTALL_TARGET
##   Name of the target for installing apk to device
## @param LAUNCH_TARGET
##   Name of the target for launching apk on device
## @param APP_NAME
##   Android application name
## @param PACKAGE_NAME
##   Android package name (com.example.appname)
##   (http://en.wikipedia.org/wiki/Java_package#Package_naming_conventions)
## @param DIRECTORY
##   Directory were to construct the apk file in
##   (e.g. "${CMAKE_BINARY_DIR}/apk")
## @param LIBRARIES
##   List of shared libraries (name of the targets) this application is using,
##   these libraries are copied into the apk file and will be loaded
##   automatically within a generated Java file - Lookout! The order is
##   important due to shared library dependencies!
## @param ASSETS
##   List of assets to copy into the apk file (absolute filenames, wildcards
##   like "*.*" are allowed)
## @param DATA_DIRECTORY
##   Subdirectory within the apk asset directory to copy the "assets"-files
##   into (e.g. "Data")
## @param MANIFEST_TEMPLATE
##   Template for creating AndroidManifest.xml
## @param ACTIVITY_LAUNCH
##   Activity name for launching
##################################################

function(android_create_apk)
  if(ANDROID AND CMAKE_VERSION VERSION_LESS "3.7")
    message(FATAL_ERROR "CMake version 3.7+ required")
  endif()

  # Tools {
  if(HUNTER_ENABLED)
    hunter_add_package(Android-SDK)
    hunter_add_package(Android-Build-Tools)

    set(_sdk_path "${ANDROID-SDK_ROOT}/android-sdk")
    set(_android_path "${_sdk_path}/tools/android")
    if(NOT EXISTS "${_android_path}")
      set(_android_path "${_sdk_path}/tools/android.bat")
    endif()
    set(
        ANDROID_ANDROID_COMMAND
        "${_android_path}"
        CACHE STRING "'android' script from Android SDK"
    )

    set(
        ANDROID_ADB_COMMAND
        "${_sdk_path}/platform-tools/adb"
        CACHE STRING "'adb' script from Android SDK"
    )
    set(
        ANDROID_ANT_COMMAND
        "ant"
        CACHE
        STRING
        "'ant' command. Linux install: 'sudo apt-get install ant'"
    )
    set(
        ANDROID_JARSIGNER_COMMAND
        "jarsigner" CACHE STRING "'jarsigner' script from Android SDK"
    )
    set(
        ANDROID_ZIPALIGN_COMMAND
        "${_sdk_path}/build-tools/${HUNTER_Android-Build-Tools_VERSION}/zipalign"
        CACHE STRING "'zipalign' script from Android SDK"
    )
  else()
    set(
        ANDROID_ANDROID_COMMAND
        "android" CACHE STRING "'android' script from Android SDK"
    )
    set(
        ANDROID_ADB_COMMAND
        "adb" CACHE STRING "'adb' script from Android SDK"
    )
    set(
        ANDROID_ANT_COMMAND
        "ant"
        CACHE
        STRING
        "'ant' command. Linux install: 'sudo apt-get install ant'"
    )
    set(
        ANDROID_JARSIGNER_COMMAND
        "jarsigner" CACHE STRING "'jarsigner' script from Android SDK"
    )
    set(
        ANDROID_ZIPALIGN_COMMAND
        "zipalign" CACHE STRING "'zipalign' script from Android SDK"
    )
  endif()
  # }

  set(optional "")
  set(
      one
      BASE_TARGET
      APK_TARGET
      INSTALL_TARGET
      LAUNCH_TARGET
      APP_NAME
      PACKAGE_NAME
      DIRECTORY
      ASSETS
      DATA_DIRECTORY
      ACTIVITY_LAUNCH
      MANIFEST_TEMPLATE
  )
  set(multiple LIBRARIES)

  cmake_parse_arguments(x "${optional}" "${one}" "${multiple}" "${ARGV}")

  # Introduce:
  # * x_BASE_TARGET
  # * x_APK_TARGET
  # * x_INSTALL_TARGET
  # * x_LAUNCH_TARGET
  # * x_APP_NAME
  # * x_PACKAGE_NAME
  # * x_DIRECTORY
  # * x_ASSETS
  # * x_DATA_DIRECTORY
  # * x_MANIFEST_TEMPLATE
  # * x_ACTIVITY_LAUNCH
  # * x_LIBRARIES

  string(COMPARE EQUAL "${x_UNPARSED_ARGUMENTS}" "" is_empty)
  if(NOT is_empty)
    message(FATAL_ERROR "Unparsed: ${x_UNPARSED_ARGUMENTS}")
  endif()

  string(COMPARE EQUAL "${x_APK_TARGET}" "" unnamed_apk_target)
  string(COMPARE EQUAL "${x_INSTALL_TARGET}" "" unnamed_install_target)
  string(COMPARE EQUAL "${x_LAUNCH_TARGET}" "" unnamed_launch_target)

  if(unnamed_apk_target AND unnamed_install_target AND unnamed_launch_target)
    message(
        FATAL_ERROR
        "At least one of the APK_TARGET/INSTALL_TARGET/LAUNCH_TARGET expected"
    )
  endif()

  # Since at least one target expected, hence apk should always be created,
  # hence variable 'create_apk_target' will be always TRUE and not needed.
  set(create_install_target FALSE)
  set(create_launch_target FALSE)

  if(NOT unnamed_install_target)
    set(create_install_target TRUE)
  endif()

  if(NOT unnamed_launch_target)
    set(create_install_target TRUE)
    set(create_launch_target TRUE)
  endif()

  apk_check_not_empty(x_DIRECTORY)
  apk_check_not_empty(x_BASE_TARGET)

  if(NOT TARGET "${x_BASE_TARGET}")
    message(FATAL_ERROR "Target not exists: ${x_BASE_TARGET}")
  endif()

  # Remove library postfix.
  # E.g. debug version have the same name for LoadLibrary
  foreach(build_type ${CMAKE_CONFIGURATION_TYPES} ${CMAKE_BUILD_TYPE})
    string(TOUPPER "${build_type}" upper_build_type)
    set_target_properties(
        "${x_BASE_TARGET}" PROPERTIES "${upper_build_type}_POSTFIX" ""
    )
  endforeach()

  string(COMPARE EQUAL "${x_PACKAGE_NAME}" "" no_package_name)
  if(no_package_name)
    set(ANDROID_APK_PACKAGE "com.example.${x_BASE_TARGET}")
  else()
    set(ANDROID_APK_PACKAGE "${x_PACKAGE_NAME}")
  endif()

  # "Run the application in fullscreen? (no status/title bar)"
  # FIXME: user control
  set(ANDROID_APK_FULLSCREEN "1")

  string(COMPARE EQUAL "${x_APP_NAME}" "" no_app_name)
  if(no_app_name)
    set(APPLICATION_NAME "${x_BASE_TARGET}")
  else()
    set(APPLICATION_NAME "${x_APP_NAME}")
  endif()

  # Get a list of libraries to load in (e.g. "PLCore;PLMath" etc.)
  set(ANDROID_SHARED_LIBRARIES_TO_LOAD "")
  list(APPEND x_LIBRARIES "${x_BASE_TARGET}") # main library must be used too
  foreach(value ${x_LIBRARIES})
    if(TARGET "${value}")
      add_dependencies("${x_BASE_TARGET}" "${value}")
      list(APPEND ANDROID_SHARED_LIBRARIES_TO_LOAD "${value}")
    else()
      if(NOT EXISTS "${value}")
        message(
            FATAL_ERROR
            "Incorrect library: ${value} (must be target or full path)"
        )
      endif()
      # "value" is e.g.:
      #   "/home/cofenberg/pl_ndk/Bin-Linux-ndk/Runtime/armeabi/libPLCore.so"
      get_filename_component(shared_library_filename ${value} NAME_WE)

      # "shared_library_filename" is e.g. "libPLCore", but we need "PLCore"
      string(LENGTH ${shared_library_filename} shared_library_filename_length)
      math(
          EXPR
          shared_library_filename_length
          "${shared_library_filename_length}-3"
      )
      string(
          SUBSTRING
          ${shared_library_filename}
          3
          ${shared_library_filename_length}
          shared_library_filename
      )

      # "shared_library_filename" is now e.g. "PLCore",
      # this is what we want -> Add it to the list
      list(APPEND ANDROID_SHARED_LIBRARIES_TO_LOAD ${shared_library_filename})
    endif()
  endforeach()

  apk_check_not_empty(_ANDROID_APK_THIS_DIRECTORY)

  # Used variables:
  # * APPLICATION_NAME
  configure_file(
      "${_ANDROID_APK_THIS_DIRECTORY}/templates/strings.xml.in"
      "${x_DIRECTORY}/res/values/strings.xml"
      @ONLY
  )

  # Create Java file which is responsible for loading in the required shared
  # libraries (the content of "ANDROID_SHARED_LIBRARIES_TO_LOAD" is used
  # for this)
  string(REPLACE "." "/" hierarchy "${ANDROID_APK_PACKAGE}")

  # Used variables:
  # * ANDROID_APK_PACKAGE
  # * ANDROID_SHARED_LIBRARIES_TO_LOAD
  configure_file(
      "${_ANDROID_APK_THIS_DIRECTORY}/templates/LoadLibraries.java.in"
      "${x_DIRECTORY}/src/${hierarchy}/LoadLibraries.java"
      @ONLY
  )

  set(ANDROID_ABI_DIR "${CMAKE_ANDROID_ARCH_ABI}")

  apk_find_tool("${ANDROID_ANDROID_COMMAND}" ANDROID_ANDROID_COMMAND_PATH)
  apk_find_tool("${ANDROID_ADB_COMMAND}" ANDROID_ADB_COMMAND_PATH)
  apk_find_tool("${ANDROID_ANT_COMMAND}" ANDROID_ANT_COMMAND_PATH)

  # Create apk file ready for release?
  # (signed, you have to enter a password during build, do also setup
  # ANDROID_APK_SIGNER_KEYSTORE and ANDROID_APK_SIGNER_ALIAS
  # FIXME: user control
  set(ANDROID_APK_RELEASE "0")

  if(ANDROID_APK_RELEASE)
    apk_find_tool("${ANDROID_JARSIGNER_COMMAND}" ANDROID_JARSIGNER_COMMAND_PATH)
    apk_find_tool("${ANDROID_ZIPALIGN_COMMAND}" ANDROID_ZIPALIGN_COMMAND_PATH)
  endif()

  if(unnamed_apk_target)
    set(apk_target_name "Android-Apk-${x_BASE_TARGET}-apk")
  else()
    set(apk_target_name "${x_APK_TARGET}")
  endif()

  add_custom_target("${apk_target_name}" DEPENDS "${x_BASE_TARGET}")

  if(unnamed_apk_target)
    set_property(GLOBAL PROPERTY USE_FOLDERS ON)
    set_property(TARGET "${apk_target_name}" PROPERTY FOLDER "Android-Apk")
  endif()

  add_custom_command(
      TARGET "${apk_target_name}"
      POST_BUILD
      COMMAND
      "${CMAKE_COMMAND}" -E remove_directory "${x_DIRECTORY}/libs"
      COMMAND
      "${CMAKE_COMMAND}" -E remove_directory "${x_DIRECTORY}/assets"
      COMMAND
      "${CMAKE_COMMAND}" -E make_directory "${x_DIRECTORY}/libs/${ANDROID_ABI_DIR}"
  )

  # Copy the used shared libraries
  foreach(value ${x_LIBRARIES})
    add_custom_command(
        TARGET "${apk_target_name}"
        POST_BUILD
        COMMAND
        "${CMAKE_COMMAND}" -E copy "$<TARGET_FILE:${value}>" "${x_DIRECTORY}/libs/${ANDROID_ABI_DIR}"
    )
  endforeach()

  string(COMPARE NOTEQUAL "${x_ASSETS}" "" has_assets)
  if(has_assets)
    apk_check_not_empty(x_DATA_DIRECTORY)
    add_custom_command(
        TARGET "${apk_target_name}"
        POST_BUILD
        COMMAND
        "${CMAKE_COMMAND}" -E make_directory "${x_DIRECTORY}/assets/${x_DATA_DIRECTORY}"
    )
    foreach(value ${x_ASSETS})
      android_copy_files(
          "${apk_target_name}"
          "${value}"
          "${x_DIRECTORY}/assets/${x_DATA_DIRECTORY}"
      )
    endforeach()
  endif()

  string(COMPARE EQUAL "${CMAKE_ANDROID_NDK}" "" is_empty)
  if(is_empty)
    message(FATAL_ERROR "CMAKE_ANDROID_NDK is empty")
  endif()

  string(COMPARE EQUAL "${CMAKE_ANDROID_ARCH}" "" is_empty)
  if(is_empty)
    message(FATAL_ERROR "CMAKE_ANDROID_ARCH is empty")
  endif()

  # Rejected: https://gitlab.kitware.com/cmake/cmake/merge_requests/74
  set(
      GDBSERVER
      "${CMAKE_ANDROID_NDK}/prebuilt/android-${CMAKE_ANDROID_ARCH}/gdbserver/gdbserver"
  )

  if(NOT EXISTS "${GDBSERVER}")
    message(FATAL_ERROR "gdbserver not found: ${GDBSERVER}")
  endif()

  add_custom_command(
      TARGET
      "${apk_target_name}"
      POST_BUILD
      COMMAND
      "${CMAKE_COMMAND}"
      "-DANDROID_ABI_DIR=${ANDROID_ABI_DIR}"
      "-DANDROID_ANDROID_COMMAND_PATH=${ANDROID_ANDROID_COMMAND_PATH}"
      "-DANDROID_ANT_COMMAND_PATH=${ANDROID_ANT_COMMAND_PATH}"
      "-DCMAKE_SYSTEM_VERSION=${CMAKE_SYSTEM_VERSION}"
      "-DANDROID_APK_PACKAGE=${ANDROID_APK_PACKAGE}"
      "-DANDROID_APK_RELEASE=${ANDROID_APK_RELEASE}"
      "-DANDROID_APK_FULLSCREEN=${ANDROID_APK_FULLSCREEN}"
      "-DANDROID_JARSIGNER_COMMAND_PATH=${ANDROID_JARSIGNER_COMMAND_PATH}"
      "-DANDROID_ZIPALIGN_COMMAND_PATH=${ANDROID_ZIPALIGN_COMMAND_PATH}"
      "-DAPK_BUILD_TYPE=$<CONFIG>"
      "-DAPPLICATION_NAME=${APPLICATION_NAME}"
      "-DGDBSERVER=${GDBSERVER}"
      "-D_ANDROID_APK_THIS_DIRECTORY=${_ANDROID_APK_THIS_DIRECTORY}"
      "-Dx_BASE_TARGET=${x_BASE_TARGET}"
      "-Dx_DIRECTORY=${x_DIRECTORY}"
      "-Dx_MANIFEST_TEMPLATE=${x_MANIFEST_TEMPLATE}"
      -P "${_ANDROID_APK_THIS_DIRECTORY}/scripts/CreateApk.cmake"
      WORKING_DIRECTORY
      "${x_DIRECTORY}"
  )

  if(ANDROID_APK_RELEASE)
    # Depends on actual build type
    set(apk_path_debug "bin/${APPLICATION_NAME}-debug.apk")
    set(apk_path_release "bin/${APPLICATION_NAME}.apk")

    set(apk_path_debug "$<$<CONFIG:Debug>:${apk_path_debug}>")
    set(apk_path_release "$<$<NOT:$<CONFIG:Debug>>:${apk_path_release}>")

    set(apk_path "${apk_path_debug}${apk_path_release}")
  else()
    # Always debug
    set(apk_path "bin/${APPLICATION_NAME}-debug.apk")
  endif()

  if(create_install_target)
    if(unnamed_install_target)
      set(install_target_name "Android-Apk-${x_BASE_TARGET}-install")
    else()
      set(install_target_name "${x_INSTALL_TARGET}")
    endif()
    add_custom_target(
        "${install_target_name}"
        "${ANDROID_ADB_COMMAND_PATH}"
        uninstall
        ${ANDROID_APK_PACKAGE}
        COMMAND
        "${ANDROID_ADB_COMMAND_PATH}"
        install
        -r
        "${apk_path}"
        WORKING_DIRECTORY
        "${x_DIRECTORY}"
        DEPENDS
        "${apk_target_name}"
    )
    if(unnamed_install_target)
      set_property(GLOBAL PROPERTY USE_FOLDERS ON)
      set_property(TARGET "${install_target_name}" PROPERTY FOLDER "Android-Apk")
    endif()
  endif()

  if("${x_ACTIVITY_LAUNCH}" STREQUAL "")
    set(activity_launch "LoadLibraries")
  else()
    set(activity_launch "${x_ACTIVITY_LAUNCH}")
  endif()

  if(create_launch_target)
    add_custom_target(
        "${x_LAUNCH_TARGET}"
        "${ANDROID_ADB_COMMAND_PATH}"
        shell
        am
        start
        -S
        -n
        "${ANDROID_APK_PACKAGE}/${ANDROID_APK_PACKAGE}.${activity_launch}"
        DEPENDS
        "${install_target_name}"
    )
  endif()
endfunction()

##################################################
## FUNCTION: android_add_test
##
## Run test on device (similar to add_test). If platform is not Android just
## add regular test.
##
## @param NAME
##   Name of the test
## @param COMMAND
##   Command to test
## @param DEVICE_BIN_DIR
##   Location of test binaries on device
##################################################

function(android_add_test)
  # Introduce:
  # * x_NAME
  # * x_COMMAND
  # * x_DEVICE_BIN_DIR
  cmake_parse_arguments(x "" "NAME;DEVICE_BIN_DIR" "COMMAND" ${ARGV})
  string(COMPARE NOTEQUAL "${x_UNPARSED_ARGUMENTS}" "" has_unparsed)
  if(has_unparsed)
    message(FATAL_ERROR "Unparsed: ${x_UNPARSED_ARGUMENTS}")
  endif()

  if(NOT ANDROID)
    add_test(NAME ${x_NAME} COMMAND ${x_COMMAND})
    return()
  endif()

  if(HUNTER_ENABLED)
    hunter_add_package(Android-SDK)
    set(ADB_COMMAND "${ANDROID-SDK_ROOT}/android-sdk/platform-tools/adb")
  else()
    set(ADB_COMMAND "adb")
  endif()

  list(GET x_COMMAND 0 app_target)
  if(NOT TARGET "${app_target}")
    message(
        FATAL_ERROR
        "Expected executable target as first argument, but got: ${app_target}"
    )
  endif()

  set(
      script_loc
      "${CMAKE_CURRENT_BINARY_DIR}/_3rdParty/AndroidTest/${x_NAME}.cmake"
  )

  list(REMOVE_AT x_COMMAND 0)
  set(APP_ARGUMENTS ${x_COMMAND})

  # Directory on device for storing applications
  string(COMPARE EQUAL "${x_DEVICE_BIN_DIR}" "" is_empty)
  if(is_empty)
    set(DEVICE_BIN_DIR "/data/local/tmp/${PROJECT_NAME}/bin")
  else()
    set(DEVICE_BIN_DIR "${x_DEVICE_BIN_DIR}")
  endif()

  set(APP_DESTINATION "${DEVICE_BIN_DIR}/${app_target}")

  # Use:
  # * ADB_COMMAND
  # * APP_ARGUMENTS
  # * APP_DESTINATION
  # * DEVICE_BIN_DIR
  configure_file(
      "${_ANDROID_APK_THIS_DIRECTORY}/templates/AndroidTest.cmake.in"
      "${script_loc}"
      @ONLY
  )

  add_test(
      NAME "${x_NAME}"
      COMMAND
          "${CMAKE_COMMAND}"
          "-DAPP_SOURCE=$<TARGET_FILE:${app_target}>"
          -P
          "${script_loc}"
  )
endfunction()
