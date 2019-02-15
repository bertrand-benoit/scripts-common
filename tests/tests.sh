#!/bin/bash
##
## Author: Bertrand Benoit <mailto:contact@bertrand-benoit.net>
## Description: Tests all features provided by utilities script.
## Version: 0.1

DEBUG_UTILITIES=1
VERBOSE=1
CATEGORY="tests:general"

currentDir=$( dirname "$( which "$0" )" )
source "$currentDir/../utilities.sh"

## Defines some constants.
declare -r ERROR_TEST_FAILURE=200


## Defines some functions.
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

# Conditional Tests.
function testConditionalBehaviour() {
  enteringTests "conditional"

  # Script should NOT break because of the pipe status ...
  [ 0 -gt 1 ] || writeMessage "fake test ..."

  exitingTests "conditional"
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
  [[ "$LAST_READ_CONFIG" != "$CONFIG_NOT_FOUND" ]] && errorMessage "Configuration feature is broken" $ERROR_TEST_FAILURE

  # Create a configuration file.
  writeMessage "Creating the temporary configuration file '$_configFile', and configuration key should then be found."
cat > $_configFile <<EOF
$_configKey="$_configValue"
EOF

  CONFIG_FILE="$_configFile"
  checkAndSetConfig "$_configKey" "$CONFIG_TYPE_OPTION"
  info "$LAST_READ_CONFIG"
  [[ "$LAST_READ_CONFIG" != "$_configValue" ]] && errorMessage "Configuration feature is broken" $ERROR_TEST_FAILURE

  # Very important to switch off this mode to keep on testing others features.
  MODE_CHECK_CONFIG_AND_QUIT=0

  exitingTests "config"
}

## Run tests.
testLoggerFeature
testConditionalBehaviour
testTimeFeature
testConfigurationFileFeature
