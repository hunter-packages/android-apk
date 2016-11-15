# Copyright (c) 2016, Ruslan Baratov
# All rights reserved.

cmake_minimum_required(VERSION 3.0)

string(COMPARE EQUAL "${APK_BUILD_TYPE}" "" is_empty)
if(is_empty)
  message(FATAL_ERROR "APK_BUILD_TYPE not set")
endif()

string(COMPARE EQUAL "${ANDROID_APK_RELEASE}" "" is_empty)
if(is_empty)
  message(FATAL_ERROR "ANDROID_APK_RELEASE not set")
endif()

string(COMPARE EQUAL "${_ANDROID_APK_THIS_DIRECTORY}" "" is_empty)
if(is_empty)
  message(FATAL_ERROR "_ANDROID_APK_THIS_DIRECTORY not set")
endif()

string(COMPARE EQUAL "${ANDROID_API_LEVEL}" "" is_empty)
if(is_empty)
  message(FATAL_ERROR "ANDROID_API_LEVEL not set")
endif()

string(COMPARE EQUAL "${ANDROID_APK_PACKAGE}" "" is_empty)
if(is_empty)
  message(FATAL_ERROR "ANDROID_APK_PACKAGE not set")
endif()

string(COMPARE EQUAL "${x_BASE_TARGET}" "" is_empty)
if(is_empty)
  message(FATAL_ERROR "x_BASE_TARGET not set")
endif()

string(COMPARE EQUAL "${APPLICATION_NAME}" "" is_empty)
if(is_empty)
  message(FATAL_ERROR "APPLICATION_NAME not set")
endif()

string(COMPARE EQUAL "${GDBSERVER}" "" is_empty)
if(is_empty)
  message(FATAL_ERROR "GDBSERVER not set")
endif()

string(COMPARE EQUAL "${ANDROID_ANDROID_COMMAND_PATH}" "" is_empty)
if(is_empty)
  message(FATAL_ERROR "ANDROID_ANDROID_COMMAND_PATH not set")
endif()

string(COMPARE EQUAL "${ANDROID_ABI_DIR}" "" is_empty)
if(is_empty)
  message(FATAL_ERROR "ANDROID_ABI_DIR not set")
endif()

string(COMPARE EQUAL "${ANDROID_ANT_COMMAND_PATH}" "" is_empty)
if(is_empty)
  message(FATAL_ERROR "ANDROID_ANT_COMMAND_PATH not set")
endif()

string(COMPARE EQUAL "${APK_BUILD_TYPE}" "Debug" is_debug)

if(is_debug)
  set(ANDROID_APK_DEBUGGABLE "true")
  set(ANDROID_APK_RELEASE_LOCAL "0")
else()
  set(ANDROID_APK_DEBUGGABLE "false")
  set(ANDROID_APK_RELEASE_LOCAL ${ANDROID_APK_RELEASE})
endif()

if(ANDROID_APK_FULLSCREEN)
  set(
      ANDROID_APK_THEME
      "android:theme=\"@android:style/Theme.NoTitleBar.Fullscreen\""
  )
else()
  set(ANDROID_APK_THEME "")
endif()

# Used variables:
# * ANDROID_API_LEVEL
# * ANDROID_APK_DEBUGGABLE
# * ANDROID_APK_PACKAGE
# * ANDROID_APK_THEME
# * x_BASE_TARGET
configure_file(
    "${_ANDROID_APK_THIS_DIRECTORY}/templates/AndroidManifest.xml.in"
    "${x_DIRECTORY}/AndroidManifest.xml"
    @ONLY
)

# Create files:
#   "build.xml"
#   "default.properties"
#   "local.properties"
#   "proguard.cfg"
execute_process(
    COMMAND
    "${ANDROID_ANDROID_COMMAND_PATH}" update project
    -t android-${ANDROID_API_LEVEL}
    --name "${APPLICATION_NAME}"
    --path "${x_DIRECTORY}"
    WORKING_DIRECTORY "${x_DIRECTORY}"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE output
)

if(NOT result EQUAL 0)
  message(FATAL_ERROR "Command failed (${result}): ${output}")
endif()

# In case of debug build, do also copy gdbserver
if(is_debug)
  if(NOT EXISTS "${GDBSERVER}")
    message(FATAL_ERROR "Not found: ${GDBSERVER}")
  endif()
  execute_process(
      COMMAND
      "${CMAKE_COMMAND}" -E copy
      "${GDBSERVER}"
      "${x_DIRECTORY}/libs/${ANDROID_ABI_DIR}"
      WORKING_DIRECTORY "${x_DIRECTORY}"
      RESULT_VARIABLE result
      OUTPUT_VARIABLE output
      ERROR_VARIABLE output
  )

  if(NOT result EQUAL 0)
    message(FATAL_ERROR "Command failed (${result}): ${output}")
  endif()
endif()

# Build the apk file
if(ANDROID_APK_RELEASE_LOCAL)
  # Let Ant create the unsigned apk file
  execute_process(
      COMMAND "${ANDROID_ANT_COMMAND_PATH}" release
      WORKING_DIRECTORY "${x_DIRECTORY}"
      RESULT_VARIABLE result
      OUTPUT_VARIABLE output
      ERROR_VARIABLE output
  )
  if(NOT result EQUAL 0)
    message(FATAL_ERROR "Command failed (${result}): ${output}")
  endif()

  # Keystore for signing the apk file (only required for release apk)
  # FIXME: user control
  set(ANDROID_APK_SIGNER_KEYSTORE "~/my-release-key.keystore")

  # Alias for signing the apk file (only required for release apk)
  # FIXME: user control
  set(ANDROID_APK_SIGNER_ALIAS "myalias")

  string(COMPARE EQUAL "${ANDROID_JARSIGNER_COMMAND_PATH}" "" is_empty)
  if(is_empty)
    message(FATAL_ERROR "ANDROID_JARSIGNER_COMMAND_PATH not set")
  endif()

  # Sign the apk file
  execute_process(
      COMMAND
      "${ANDROID_JARSIGNER_COMMAND_PATH}"
      -verbose
      -keystore "${ANDROID_APK_SIGNER_KEYSTORE}"
      "bin/${APPLICATION_NAME}-unsigned.apk"
      "${ANDROID_APK_SIGNER_ALIAS}"
      WORKING_DIRECTORY "${x_DIRECTORY}"
      RESULT_VARIABLE result
      OUTPUT_VARIABLE output
      ERROR_VARIABLE output
  )
  if(NOT result EQUAL 0)
    message(FATAL_ERROR "Command failed (${result}): ${output}")
  endif()

  string(COMPARE EQUAL "${ANDROID_ZIPALIGN_COMMAND_PATH}" "" is_empty)
  if(is_empty)
    message(FATAL_ERROR "ANDROID_ZIPALIGN_COMMAND_PATH not set")
  endif()

  # Align the apk file
  execute_process(
      COMMAND
      "${ANDROID_ZIPALIGN_COMMAND_PATH}"
      -v -f 4 "bin/${APPLICATION_NAME}-unsigned.apk" "bin/${APPLICATION_NAME}.apk"
      WORKING_DIRECTORY "${x_DIRECTORY}"
      RESULT_VARIABLE result
      OUTPUT_VARIABLE output
      ERROR_VARIABLE output
  )
  if(NOT result EQUAL 0)
    message(FATAL_ERROR "Command failed (${result}): ${output}")
  endif()
else()
  execute_process(
      COMMAND
      "${ANDROID_ANT_COMMAND_PATH}" debug
      WORKING_DIRECTORY "${x_DIRECTORY}"
      RESULT_VARIABLE result
      OUTPUT_VARIABLE output
      ERROR_VARIABLE output
  )
  if(NOT result EQUAL 0)
    message(FATAL_ERROR "Command failed (${result}): ${output}")
  endif()
endif()
