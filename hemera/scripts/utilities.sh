#!/bin/bash
#
# Author: Bertrand BENOIT <bertrand.benoit@bsquare.no-ip.org>
# Version: 1.0
# Description: provides lots of utilities functions.

#########################
## Global variables
verbose=0
category="general"

#########################
## Functions - various

# usage: writeMessage <message> [<0 or 1>]
# 0: keep on the same line
# 1: move to next line
function writeMessage() {
  local message="$1"
  messageTime=$(date +"%d/%m/%y %H:%M.%S")

  echoOption="-e"
  [ ! -z "$2" ] && [ "$2" -eq 0 ] && echoOption="-ne"

  echo $echoOption "$messageTime  [$category]  $message"
}

# usage: info <message> [<0 or 1>]
# Shows message only if verbose is ON.
function info() {
  [ $verbose -eq 0 ] && return 0
  local message="$1"
  shift
  writeMessage "$message" $*
}

# usage: errorMessage <message> [<exit code>]
# Shows error message and exits.
function errorMessage() {
  local message="$1"
  messageTime=$(date +"%d/%m/%y %H:%M.%S")
  echo -e "$messageTime  [$category]  \E[31m\E[4mERROR\E[0m: $message" >&2
  exit ${2:-100}
}

# usage: checkBin <binary name/path>
function checkBin() {
  info "Checking binary: $1"
  which "$1" >/dev/null 2>&1 && return 0
  errorMessage "Unable to find binary $1." 126
}

# usage: checkDataFile <data file path>
function checkDataFile() {
  info "Checking data file: $1"
  [ -f "$1" ] && return 0
  errorMessage "Unable to find data file '$1'." 126
}

#########################
## Functions - configuration

# usage: getConfigValue <config key>
function getConfigValue() {
  value=$( grep -re "^$1=" "$configurationFile" |sed -e 's/^[^=]*=//;s/"//g;' )
  [ -z "$value" ] && errorMessage "$1 configuration key not found"
  echo "$value"
}

# usage: getConfigValue <supported values> <value to check>
function checkAvailableValue() {
  [ $( echo "$1" |grep -w "$2" |wc -l ) -eq 1 ]
}

# usage: getConfigPath <config key>
function getConfigPath() {
  value=$( getConfigValue "$1" ) || return 1
  
  # Checks if it is an absolute path.
  if [[ "$value" =~ "^\/.*$" ]]; then
    echo "$value"
    return 0
  fi
  
  # Checks if it is a "simple" path.
  if [[ "$value" =~ "^[^\/]*$" ]]; then
    echo "$value"
    return 0
  fi
  
  # Prefixes with Hemera install directory path.
  echo "$installDir/$value"  
}

