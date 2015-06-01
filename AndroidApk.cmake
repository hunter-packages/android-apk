#*********************************************************#
#*  File: AndroidApk.cmake                                *
#*    Android apk tools
#*
#*  Copyright (C) 2002-2013 The PixelLight Team (http://www.pixellight.org/)
#*  Copyright (C) 2015 Ruslan Baratov
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

##################################################
## Tools
##################################################

if(HUNTER_ENABLED)
  hunter_add_package(Android-SDK)
  hunter_add_package(Android-Build-Tools)

  set(_sdk_path "${ANDROID-SDK_ROOT}/android-sdk")
  set(
      ANDROID_ANDROID_COMMAND
      "${_sdk_path}/tools/android"
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
set(ANDROID_THIS_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")

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
  if(XCODE OR MSCV_IDE)
    message(
        FATAL_ERROR
        "Only for single-configuration generators (like 'Unix Makefiles')"
    )
  endif()

  cmake_parse_arguments(
      apk "" "NAME;DIRECTORY;ASSETS;DATA_DIRECTORY" "LIBRARIES" ${ARGV}
  )
  # apk_NAME
  # apk_DIRECTORY
  # apk_ASSETS
  # apk_DATA_DIRECTORY
  # apk_LIBRARIES

  string(COMPARE EQUAL "${apk_UNPARSED_ARGUMENTS}" "" is_empty)
  if(NOT is_empty)
    message(FATAL_ERROR "Unparsed: ${apk_UNPARSED_ARGUMENTS}")
  endif()

  apk_check_not_empty(apk_DIRECTORY)
  apk_check_not_empty(apk_NAME)

  if(NOT TARGET "${apk_NAME}")
    message(FATAL_ERROR "Target not exists: ${apk_NAME}")
  endif()

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

  set(ANDROID_NAME "${apk_NAME}")
  apk_check_not_empty(ANDROID_NAME)

  if(CMAKE_BUILD_TYPE MATCHES Debug)
    set(ANDROID_APK_DEBUGGABLE "true")
    set(ANDROID_APK_RELEASE_LOCAL "0")
  else()
    set(ANDROID_APK_DEBUGGABLE "false")
    set(ANDROID_APK_RELEASE_LOCAL ${ANDROID_APK_RELEASE})
  endif()

  apk_check_not_empty(ANDROID_THIS_DIRECTORY)

  # Create "AndroidManifest.xml"
  configure_file(
      "${ANDROID_THIS_DIRECTORY}/templates/AndroidManifest.xml.in"
      "${apk_DIRECTORY}/AndroidManifest.xml"
      @ONLY
  )

  # Create "res/values/strings.xml" (Note: ANDROID_NAME used)
  configure_file(
      "${ANDROID_THIS_DIRECTORY}/templates/strings.xml.in"
      "${apk_DIRECTORY}/res/values/strings.xml"
      @ONLY
  )

  # Get a list of libraries to load in (e.g. "PLCore;PLMath" etc.)
  set(ANDROID_SHARED_LIBRARIES_TO_LOAD "")
  list(APPEND apk_LIBRARIES "${ANDROID_NAME}") # main library must be used too
  foreach(value ${apk_LIBRARIES})
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
  set(x "${apk_DIRECTORY}/src/${ANDROID_APK_TOP_LEVEL_DOMAIN}")
  set(
      x
      "${x}/${ANDROID_APK_DOMAIN}/${ANDROID_APK_SUBDOMAIN}/LoadLibraries.java"
  )
  configure_file(
      "${ANDROID_THIS_DIRECTORY}/templates/LoadLibraries.java.in"
      "${x}"
      @ONLY
  )

  apk_check_not_empty(ANDROID_ABI)

  # Create the directory for the libraries
  add_custom_command(TARGET "${ANDROID_NAME}"
      PRE_BUILD
      COMMAND ${CMAKE_COMMAND} -E remove_directory "${apk_DIRECTORY}/libs"
  )
  add_custom_command(TARGET "${ANDROID_NAME}"
      PRE_BUILD
      COMMAND
      "${CMAKE_COMMAND}"
      -E
      make_directory
      "${apk_DIRECTORY}/libs/${ANDROID_ABI}"
  )

  # Copy the used shared libraries
  foreach(value ${apk_LIBRARIES})
    add_custom_command(TARGET ${ANDROID_NAME}
        POST_BUILD
        COMMAND
        "${CMAKE_COMMAND}"
        -E
        copy
        "$<TARGET_FILE:${value}>"
        "${apk_DIRECTORY}/libs/${ANDROID_ABI}"
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
          --path "${apk_DIRECTORY}"
  )

  # Copy assets
  add_custom_command(TARGET ${ANDROID_NAME}
    PRE_BUILD
    COMMAND "${CMAKE_COMMAND}" -E remove_directory "${apk_DIRECTORY}/assets"
  )
  string(COMPARE NOTEQUAL "${apk_ASSETS}" "" has_assets)
  if(has_assets)
    apk_check_not_empty(apk_DATA_DIRECTORY)
    add_custom_command(
        TARGET ${ANDROID_NAME} PRE_BUILD
        COMMAND
            "${CMAKE_COMMAND}" -E make_directory
            "${apk_DIRECTORY}/assets/${apk_DATA_DIRECTORY}"
    )
    foreach(value ${apk_ASSETS})
      android_copy_files(
          "${ANDROID_NAME}"
          "${value}"
          "${apk_DIRECTORY}/assets/${apk_DATA_DIRECTORY}"
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
            "${apk_DIRECTORY}/libs/${ANDROID_ABI}"
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
        WORKING_DIRECTORY "${apk_DIRECTORY}"
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
        WORKING_DIRECTORY "${apk_DIRECTORY}"
    )

    apk_find_tool("${ANDROID_ZIPALIGN_COMMAND}" ANDROID_ZIPALIGN_COMMAND_PATH)
    # Align the apk file
    add_custom_command(TARGET ${ANDROID_NAME}
        COMMAND
            "${ANDROID_ZIPALIGN_COMMAND_PATH}"
            -v -f 4 "bin/${ANDROID_NAME}-unsigned.apk" "bin/${ANDROID_NAME}.apk"
        WORKING_DIRECTORY "${apk_DIRECTORY}"
    )

    # Install current version on the device/emulator
    if(ANDROID_APK_INSTALL OR ANDROID_APK_RUN)
      add_custom_command(TARGET ${ANDROID_NAME}
          COMMAND
              "${ANDROID_ADB_COMMAND_PATH}"
              install -r "bin/${ANDROID_NAME}.apk"
          WORKING_DIRECTORY "${apk_DIRECTORY}"
      )
    endif()
  else()
    # Let Ant create the unsigned apk file
    add_custom_command(TARGET ${ANDROID_NAME}
        COMMAND "${ANDROID_ANT_COMMAND_PATH}" debug
        WORKING_DIRECTORY "${apk_DIRECTORY}"
    )

    # Install current version on the device/emulator
    if(ANDROID_APK_INSTALL OR ANDROID_APK_RUN)
      add_custom_command(TARGET ${ANDROID_NAME}
          COMMAND
              "${ANDROID_ADB_COMMAND_PATH}"
              install -r "bin/${ANDROID_NAME}-debug.apk"
          WORKING_DIRECTORY "${apk_DIRECTORY}"
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
