#!/bin/bash
##
## Author: Bertrand Benoit <mailto:contact@bertrand-benoit.net>
## Description: Tests all features provided by utilities script.
## Version: 0.1

DEBUG_UTILITIES=1
VERBOSE=1
CATEGORY="tests:general"
ERROR_MESSAGE_EXITS_SCRIPT=0

currentDir=$( dirname "$( which "$0" )" )
source "$currentDir/../utilities.sh"

## Defines some constants.
declare -r ERROR_TEST_FAILURE=200


## Defines some functions.
# usage: testFail <message>
function testFail() {
  errorMessage "$1" "$ERROR_TEST_FAILURE"
  exit "$ERROR_TEST_FAILURE"
}

# usage: enteringTests <test category>
function enteringTests() {
  local _testCategory="$1"
  CATEGORY="tests:$_testCategory"

  info "$_testCategory feature tests - BEGIN"
}

# usage: exitingTests <test category>
function exitingTests() {
  local _testCategory="$1"
  CATEGORY="tests:general"

  info "$_testCategory feature tests - END"
}

## Define Tests functions.
# Logger feature Tests.
function testLoggerFeature() {
  enteringTests "logger"

  writeMessage "Simple message tests (should not have prefix)"
  info "Info message test"
  warning "Warning message test"
  errorMessage "Error message test" -1 # -1 to avoid automatic exit of the script

  exitingTests "logger"
}

# Robustness Tests.
function testRobustness() {
  local _logLevel _message _sameLine _exitStatus

  enteringTests "robustness"

  _logLevel="$LOG_LEVEL_MESSAGE"
  _message="Simple message"
  _newLine="1"
  _exitStatus="-1"

  # doWriteMessage should NOT be called directly, but user can still do it, ensures robustness on parameters control.
  # Log level
 _doWriteMessage "Broken Log level ..." "$_message" "$_newLine" "$_exitStatus"

  # Message
 _doWriteMessage "$_logLevel" "Message on \
                                several \
                                lines" "$_newLine" "$_exitStatus"

 _doWriteMessage "$_logLevel" "Message on \nseveral \nlines" "$_newLine" "$_exitStatus"
  # New line.
 _doWriteMessage "$_logLevel" "$_message" "Bad value" "$_exitStatus"

  # Exit status.
 _doWriteMessage "$_logLevel" "$_message" "$_newLine" "Bad value"

  exitingTests "robustness"
}

# Conditional Tests.
function testConditionalBehaviour() {
  enteringTests "conditional"

  # Script should NOT break because of the pipe status ...
  [ 0 -gt 1 ] || writeMessage "fake test ..."

  exitingTests "conditional"
}

# Version feature Tests.
function testVersionFeature() {
  local _fileWithVersion _version _fakeVersion
  enteringTests "version"

  _fileWithVersion="$currentDir/../README.md"
  _version=$( getVersion "$_fileWithVersion" )
  _fakeVersion="999.999.999"

  writeMessage "scripts-common Utilities version: $_version"
  writeMessage "scripts-common Utilities detailed version: $( getDetailedVersion "$_version" "$currentDir/.." )"

  writeMessage "Checking if $_version is greater than $_fakeVersion ... (should NOT be the case)"
  isVersionGreater "$_version" "$_fakeVersion" && testFail "Version feature is broken" $ERROR_TEST_FAILURE

  writeMessage "Checking if $_fakeVersion is greater than $_version ... (should be the case)"
  ! isVersionGreater "$_fakeVersion" "$_version" && testFail "Version feature is broken" $ERROR_TEST_FAILURE

  exitingTests "version"
}

# Time feature Tests.
function testTimeFeature() {
  enteringTests "time"

  info "Testing time feature"
  initializeStartTime
  sleep 1
  writeMessage "Uptime: $( getUptime )"

  exitingTests "time"
}

# Configuration file feature Tests.
function testConfigurationFileFeature() {
  local _configKey="my.config.key"
  local _configValue="my Value"
  local _configFile="$DEFAULT_TMP_DIR/localConfigurationFile.conf"

  enteringTests "config"

  writeMessage "A configuration key '$CONFIG_NOT_FOUND' should happen."

  # To avoid error when configuration key is not found, switch on this mode.
  MODE_CHECK_CONFIG_AND_QUIT=1

  # No configuration file defined, it should not be found.
  checkAndSetConfig "$_configKey" "$CONFIG_TYPE_OPTION"
  [[ "$LAST_READ_CONFIG" != "$CONFIG_NOT_FOUND" ]] && testFail "Configuration feature is broken" $ERROR_TEST_FAILURE

  # Create a configuration file.
  writeMessage "Creating the temporary configuration file '$_configFile', and configuration key should then be found."
cat > $_configFile <<EOF
$_configKey="$_configValue"
EOF

  CONFIG_FILE="$_configFile"
  checkAndSetConfig "$_configKey" "$CONFIG_TYPE_OPTION"
  info "$LAST_READ_CONFIG"
  [[ "$LAST_READ_CONFIG" != "$_configValue" ]] && testFail "Configuration feature is broken" $ERROR_TEST_FAILURE

  # Very important to switch off this mode to keep on testing others features.
  MODE_CHECK_CONFIG_AND_QUIT=0

  exitingTests "config"
}

# Lines feature Tests.
function testLinesFeature() {
  local _fileToCheck _fromLine _toLine _result
  _fileToCheck="$0"
  _fromLine=4
  _toLine=8

  enteringTests "lines"

  # TODO: creates a dedicated test file, and ensures the result ... + test all limit cases
  writeMessage "Getting lines of file '$_fileToCheck', from line '$_fromLine'"
  _result=$( getLastLinesFromN "$_fileToCheck" "$_fromLine" ) || testFail "Lines feature is broken" $ERROR_TEST_FAILURE

  writeMessage "Getting lines of file '$_fileToCheck', from line '$_fromLine', to line '$_toLine'"
  _result=$( getLinesFromNToP "$_fileToCheck" "$_fromLine" "$_toLine" ) || testFail "Lines feature is broken" $ERROR_TEST_FAILURE
  [ "$( echo "$_result" |wc -l )" -ne $((_toLine - _fromLine + 1)) ] && testFail "Lines feature is broken" $ERROR_TEST_FAILURE

  exitingTests "lines"
}

# PID file fature Tests.
# Tests PID file feature, without the Daemon layer which is tested elsewhere.
function testPidFileFeature() {
  local _pidFile _processName
  enteringTests "pidFiles"

  _pidFile="$DEFAULT_PID_DIR/testPidFileFeature.pid"
  _processName="testPidFileFeature"

  # Limit tests, on not existing PID file.
  rm -f "$_pidFile"
  writeMessage "deletePIDFile on not existing file, must NOT fail"
  deletePIDFile "$_pidFile" || testFail "PID files feature is broken" $ERROR_TEST_FAILURE

  writeMessage "getPIDFromFile with a not existing file, must produce an ERROR"
  getPIDFromFile "$_pidFile" && testFail "PID files feature is broken" $ERROR_TEST_FAILURE

  writeMessage "getProcessNameFromFile with a not existing file, must produce an ERROR"
  getProcessNameFromFile "$_pidFile" && testFail "PID files feature is broken" $ERROR_TEST_FAILURE

  writeMessage "isRunningProcess with a not existing file, must produce an ERROR"
  isRunningProcess "$_pidFile" "$0" && testFail "PID files feature is broken" $ERROR_TEST_FAILURE

  # Normal situation.
  writeMessage "Create properly a PID file for this process"
  writePIDFile "$_pidFile" "$0" || testFail "PID files feature is broken" $ERROR_TEST_FAILURE
  writeMessage "Trying to write in the existing PID file, must produce an ERROR"
  writePIDFile "$_pidFile" "$0" && testFail "PID files feature is broken" $ERROR_TEST_FAILURE

  writeMessage "Check if system consider this process as still running"
  isRunningProcess "$_pidFile" "$0" || testFail "PID files feature is broken" $ERROR_TEST_FAILURE

  writeMessage "Delete the PID file"
  deletePIDFile "$_pidFile" || testFail "PID files feature is broken" $ERROR_TEST_FAILURE

  exitingTests "pidFiles"
}

## Run tests.
testRobustness
testLoggerFeature
testConditionalBehaviour
testVersionFeature
testTimeFeature
testConfigurationFileFeature
testPidFileFeature
testLinesFeature

writeMessage "All Tests are successful !"
