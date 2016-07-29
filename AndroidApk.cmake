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

##################################################
## Options
##################################################
set(ANDROID_APK_CREATE "1" CACHE BOOL "Create apk file?")
set(
    ANDROID_APK_INSTALL "1" CACHE BOOL
    "Install created apk file on the device automatically?"
)
set(
    ANDROID_APK_RUN "1" CACHE BOOL
    "Run created apk file on the device automatically? \
(installs it automatically as well, \"ANDROID_APK_INSTALL\"-option is ignored)"
)
set(
    ANDROID_APK_TOP_LEVEL_DOMAIN "org" CACHE STRING
    "Top level domain name of the organization \
(follow the package naming conventions \
(http://en.wikipedia.org/wiki/Java_package#Package_naming_conventions))"
)
set(
    ANDROID_APK_DOMAIN "pixellight" CACHE STRING
    "Organization's domain (follow the package naming conventions \
(http://en.wikipedia.org/wiki/Java_package#Package_naming_conventions))"
)
set(
    ANDROID_APK_SUBDOMAIN "test" CACHE STRING
    "Any subdomains (follow the package naming conventions \
(http://en.wikipedia.org/wiki/Java_package#Package_naming_conventions))"
)
set(
    ANDROID_APK_FULLSCREEN "1" CACHE BOOL
    "Run the application in fullscreen? (no status/title bar)"
)
set(
    ANDROID_APK_RELEASE "0" CACHE BOOL
    "Create apk file ready for release? \
(signed, you have to enter a password during build, do also setup \
\"ANDROID_APK_SIGNER_KEYSTORE\" and \"ANDROID_APK_SIGNER_ALIAS\")"
)
set(
    ANDROID_APK_SIGNER_KEYSTORE "~/my-release-key.keystore" CACHE STRING
    "Keystore for signing the apk file (only required for release apk)"
)
set(
    ANDROID_APK_SIGNER_ALIAS "myalias" CACHE STRING
    "Alias for signing the apk file (only required for release apk)"
)
set(
    ANDROID_APK_APP_DESTINATION "/data/local/tmp/AndroidApk" CACHE STRING
    "Directory on device for storing applications"
)

##################################################
## Tools
##################################################

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

##################################################
## Variables
##################################################

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
function(android_copy_files targetname src dest)
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

  # Find files
  foreach(file ${files})
    # Get source and destination file
    set(src_file "${path}/${file}")
    set(dst_file "${dest}/${file}")

    # Create output directory
    get_filename_component(dst_path "${dst_file}" PATH)
    file(MAKE_DIRECTORY "${dst_path}")

    # Copy file
    add_custom_command(
        TARGET "${targetname}" PRE_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy "${src_file}" "${dst_file}" VERBATIM
    )
  endforeach()
endfunction()

##################################################
## FUNCTION: android_create_apk
##
## Create/copy Android apk related files
##
## @param NAME
##   Name of the project (e.g. "MyProject"), this will also be the name of the
##   created apk file
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
##################################################

function(android_create_apk)
  if(XCODE OR MSVC_IDE)
    message(
        FATAL_ERROR
        "Only for single-configuration generators (like 'Unix Makefiles')"
    )
  endif()

  set(optional "")
  set(one NAME DIRECTORY ASSETS DATA_DIRECTORY)
  set(multiple LIBRARIES)

  cmake_parse_arguments(x "${optional}" "${one}" "${multiple}" "${ARGV}")

  # Introduce:
  # * x_NAME
  # * x_DIRECTORY
  # * x_ASSETS
  # * x_DATA_DIRECTORY
  # * x_LIBRARIES

  string(COMPARE EQUAL "${x_UNPARSED_ARGUMENTS}" "" is_empty)
  if(NOT is_empty)
    message(FATAL_ERROR "Unparsed: ${x_UNPARSED_ARGUMENTS}")
  endif()

  apk_check_not_empty(x_DIRECTORY)
  apk_check_not_empty(x_NAME)

  if(NOT TARGET "${x_NAME}")
    message(FATAL_ERROR "Target not exists: ${x_NAME}")
  endif()

  # Remove library postfix.
  # E.g. debug version have the same name for LoadLibrary
  string(TOUPPER "${CMAKE_BUILD_TYPE}" upper_build_type)
  set_target_properties(
      "${x_NAME}" PROPERTIES "${upper_build_type}_POSTFIX" ""
  )

  if(NOT ANDROID_APK_CREATE)
    return()
  endif()

  apk_check_not_empty(ANDROID_APK_TOP_LEVEL_DOMAIN)
  apk_check_not_empty(ANDROID_APK_DOMAIN)
  apk_check_not_empty(ANDROID_APK_SUBDOMAIN)

  # Construct the current package name and theme
  set(ANDROID_APK_PACKAGE "${ANDROID_APK_TOP_LEVEL_DOMAIN}")
  set(ANDROID_APK_PACKAGE "${ANDROID_APK_PACKAGE}.${ANDROID_APK_DOMAIN}")
  set(ANDROID_APK_PACKAGE "${ANDROID_APK_PACKAGE}.${ANDROID_APK_SUBDOMAIN}")

  if(ANDROID_APK_FULLSCREEN)
    set(
        ANDROID_APK_THEME
        "android:theme=\"@android:style/Theme.NoTitleBar.Fullscreen\""
    )
  else()
    set(ANDROID_APK_THEME "")
  endif()

  set(ANDROID_NAME "${x_NAME}")
  apk_check_not_empty(ANDROID_NAME)

  if(CMAKE_BUILD_TYPE MATCHES Debug)
    set(ANDROID_APK_DEBUGGABLE "true")
    set(ANDROID_APK_RELEASE_LOCAL "0")
  else()
    set(ANDROID_APK_DEBUGGABLE "false")
    set(ANDROID_APK_RELEASE_LOCAL ${ANDROID_APK_RELEASE})
  endif()

  apk_check_not_empty(_ANDROID_APK_THIS_DIRECTORY)

  # Create "AndroidManifest.xml"
  configure_file(
      "${_ANDROID_APK_THIS_DIRECTORY}/templates/AndroidManifest.xml.in"
      "${x_DIRECTORY}/AndroidManifest.xml"
      @ONLY
  )

  # Create "res/values/strings.xml" (Note: ANDROID_NAME used)
  configure_file(
      "${_ANDROID_APK_THIS_DIRECTORY}/templates/strings.xml.in"
      "${x_DIRECTORY}/res/values/strings.xml"
      @ONLY
  )

  # Get a list of libraries to load in (e.g. "PLCore;PLMath" etc.)
  set(ANDROID_SHARED_LIBRARIES_TO_LOAD "")
  list(APPEND x_LIBRARIES "${ANDROID_NAME}") # main library must be used too
  foreach(value ${x_LIBRARIES})
    if(TARGET "${value}")
      add_dependencies("${ANDROID_NAME}" "${value}")
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

  # Create Java file which is responsible for loading in the required shared
  # libraries (the content of "ANDROID_SHARED_LIBRARIES_TO_LOAD" is used
  # for this)
  set(x "${x_DIRECTORY}/src/${ANDROID_APK_TOP_LEVEL_DOMAIN}")
  set(
      x
      "${x}/${ANDROID_APK_DOMAIN}/${ANDROID_APK_SUBDOMAIN}/LoadLibraries.java"
  )
  configure_file(
      "${_ANDROID_APK_THIS_DIRECTORY}/templates/LoadLibraries.java.in"
      "${x}"
      @ONLY
  )

  apk_check_not_empty(ANDROID_ABI)

  # Special case for ANDROID_ABI == "armv7a with NEON"
  # which results in INSTALL_FAILED_NO_MATCHING_ABIS during installation
  # This creates a separate variable for teh ANDROID_ABI_DIR omitting "with NEON"
  string(REGEX REPLACE " with NEON" "" ANDROID_ABI_DIR "${ANDROID_ABI}")

  # Create the directory for the libraries
  add_custom_command(TARGET "${ANDROID_NAME}"
      PRE_BUILD
      COMMAND ${CMAKE_COMMAND} -E remove_directory "${x_DIRECTORY}/libs"
  )
  add_custom_command(TARGET "${ANDROID_NAME}"
      PRE_BUILD
      COMMAND
      "${CMAKE_COMMAND}"
      -E
      make_directory
      "${x_DIRECTORY}/libs/${ANDROID_ABI_DIR}"
  )

  # Copy the used shared libraries
  foreach(value ${x_LIBRARIES})
    add_custom_command(TARGET ${ANDROID_NAME}
        POST_BUILD
        COMMAND
        "${CMAKE_COMMAND}"
        -E
        copy
        "$<TARGET_FILE:${value}>"
        "${x_DIRECTORY}/libs/${ANDROID_ABI_DIR}"
    )
  endforeach()

  apk_check_not_empty(ANDROID_API_LEVEL)
  apk_find_tool("${ANDROID_ANDROID_COMMAND}" ANDROID_ANDROID_COMMAND_PATH)

  # Create files:
  #   "build.xml"
  #   "default.properties"
  #   "local.properties"
  #   "proguard.cfg"
  add_custom_command(
      TARGET ${ANDROID_NAME}
      COMMAND
          "${ANDROID_ANDROID_COMMAND_PATH}" update project
          -t android-${ANDROID_API_LEVEL}
          --name ${ANDROID_NAME}
          --path "${x_DIRECTORY}"
  )

  # Copy assets
  add_custom_command(TARGET ${ANDROID_NAME}
    PRE_BUILD
    COMMAND "${CMAKE_COMMAND}" -E remove_directory "${x_DIRECTORY}/assets"
  )
  string(COMPARE NOTEQUAL "${x_ASSETS}" "" has_assets)
  if(has_assets)
    apk_check_not_empty(x_DATA_DIRECTORY)
    add_custom_command(
        TARGET ${ANDROID_NAME} PRE_BUILD
        COMMAND
            "${CMAKE_COMMAND}" -E make_directory
            "${x_DIRECTORY}/assets/${x_DATA_DIRECTORY}"
    )
    foreach(value ${x_ASSETS})
      android_copy_files(
          "${ANDROID_NAME}"
          "${value}"
          "${x_DIRECTORY}/assets/${x_DATA_DIRECTORY}"
      )
    endforeach()
  endif()

  # In case of debug build, do also copy gdbserver
  if(CMAKE_BUILD_TYPE MATCHES Debug)
    apk_check_not_empty(CMAKE_GDBSERVER)
    add_custom_command(TARGET ${ANDROID_NAME}
        POST_BUILD
        COMMAND
            "${CMAKE_COMMAND}" -E copy
            "${CMAKE_GDBSERVER}"
            "${x_DIRECTORY}/libs/${ANDROID_ABI_DIR}"
    )
  endif()

  # Uninstall previous version from the device/emulator
  # (else we may get e.g. signature conflicts)
  apk_find_tool("${ANDROID_ADB_COMMAND}" ANDROID_ADB_COMMAND_PATH)
  add_custom_command(TARGET ${ANDROID_NAME}
      COMMAND "${ANDROID_ADB_COMMAND_PATH}" uninstall ${ANDROID_APK_PACKAGE}
  )

  apk_find_tool("${ANDROID_ANT_COMMAND}" ANDROID_ANT_COMMAND_PATH)

  # Build the apk file
  if(ANDROID_APK_RELEASE_LOCAL)
    # Let Ant create the unsigned apk file
    add_custom_command(TARGET ${ANDROID_NAME}
        COMMAND "${ANDROID_ANT_COMMAND_PATH}" release
        WORKING_DIRECTORY "${x_DIRECTORY}"
    )

    apk_check_not_empty(ANDROID_APK_SIGNER_ALIAS)
    apk_check_not_empty(ANDROID_APK_SIGNER_KEYSTORE)

    apk_find_tool("${ANDROID_JARSIGNER_COMMAND}" ANDROID_JARSIGNER_COMMAND_PATH)
    # Sign the apk file
    add_custom_command(TARGET ${ANDROID_NAME}
        COMMAND
            "${ANDROID_JARSIGNER_COMMAND_PATH}"
            -verbose
            -keystore "${ANDROID_APK_SIGNER_KEYSTORE}"
            "bin/${ANDROID_NAME}-unsigned.apk"
            "${ANDROID_APK_SIGNER_ALIAS}"
        WORKING_DIRECTORY "${x_DIRECTORY}"
    )

    apk_find_tool("${ANDROID_ZIPALIGN_COMMAND}" ANDROID_ZIPALIGN_COMMAND_PATH)
    # Align the apk file
    add_custom_command(TARGET ${ANDROID_NAME}
        COMMAND
            "${ANDROID_ZIPALIGN_COMMAND_PATH}"
            -v -f 4 "bin/${ANDROID_NAME}-unsigned.apk" "bin/${ANDROID_NAME}.apk"
        WORKING_DIRECTORY "${x_DIRECTORY}"
    )

    # Install current version on the device/emulator
    if(ANDROID_APK_INSTALL OR ANDROID_APK_RUN)
      add_custom_command(TARGET ${ANDROID_NAME}
          COMMAND
              "${ANDROID_ADB_COMMAND_PATH}"
              install -r "bin/${ANDROID_NAME}.apk"
          WORKING_DIRECTORY "${x_DIRECTORY}"
      )
    endif()
  else()
    # Let Ant create the unsigned apk file
    add_custom_command(TARGET ${ANDROID_NAME}
        COMMAND "${ANDROID_ANT_COMMAND_PATH}" debug
        WORKING_DIRECTORY "${x_DIRECTORY}"
    )

    # Install current version on the device/emulator
    if(ANDROID_APK_INSTALL OR ANDROID_APK_RUN)
      add_custom_command(TARGET ${ANDROID_NAME}
          COMMAND
              "${ANDROID_ADB_COMMAND_PATH}"
              install -r "bin/${ANDROID_NAME}-debug.apk"
          WORKING_DIRECTORY "${x_DIRECTORY}"
      )
    endif()
  endif()

  # Start the application
  if(ANDROID_APK_RUN)
    add_custom_command(TARGET ${ANDROID_NAME}
        COMMAND
        "${ANDROID_ADB_COMMAND_PATH}"
        shell
        am
        start
        -n
        "${ANDROID_APK_PACKAGE}/${ANDROID_APK_PACKAGE}.LoadLibraries"
    )
  endif()
endfunction()

##################################################
## FUNCTION: android_add_test
##
## Run test on device (similar to add_test)
##
## @param NAME
##   Name of the test
## @param COMMAND
##   Command to test
##################################################

function(android_add_test)
  if(HUNTER_ENABLED)
    hunter_add_package(Android-SDK)
    set(ADB_COMMAND "${ANDROID-SDK_ROOT}/android-sdk/platform-tools/adb")
  else()
    set(ADB_COMMAND "adb")
  endif()

  # Introduce:
  # * x_NAME
  # * x_COMMAND
  cmake_parse_arguments(x "" "NAME" "COMMAND" ${ARGV})
  string(COMPARE NOTEQUAL "${x_UNPARSED_ARGUMENTS}" "" has_unparsed)
  if(has_unparsed)
    message(FATAL_ERROR "Unparsed: ${x_UNPARSED_ARGUMENTS}")
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

  set(APP_DESTINATION "${ANDROID_APK_APP_DESTINATION}")
  set(APP_DESTINATION "${APP_DESTINATION}/${PROJECT_NAME}/AndroidTest")
  set(APP_DESTINATION "${APP_DESTINATION}/${x_NAME}/${app_target}")

  # Use:
  # * ADB_COMMAND
  # * APP_ARGUMENTS
  # * APP_DESTINATION
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
