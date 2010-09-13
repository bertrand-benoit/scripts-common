#!/bin/bash
#
# Author: Bertrand BENOIT <projettwk@users.sourceforge.net>
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
  # Checks if the key exists.
  [ $( grep -re "^$1=" "$configurationFile" |wc -l ) -eq 0 ] && errorMessage "$1 configuration key not found"

  # Gets the value (may be empty).
  grep -re "^$1=" "$configurationFile" |sed -e 's/^[^=]*=//;s/"//g;'
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

#########################
## Functions - source code management
# usage: manageJavaHome
function manageJavaHome() {
  # Checks if environment variable JAVA_HOME is defined.
  if [ -z "$JAVA_HOME" ]; then
    # Checks if it is defined in configuration file.
    javaHome=$( getConfigValue "$CONFIG_KEY.java.home" ) || exit 100
    [ -z "$javaHome" ] && errorMessage "You must either configure JAVA_HOME environment variable or $CONFIG_KEY.java.home configuration element."
    
    # Ensures it exists.
    [ ! -d "$javaHome" ] && errorMessage "$CONFIG_KEY.java.home defined $javaHome which is not found."
    
    export JAVA_HOME="$javaHome"
  fi
  
  # Ensures it is a jdk home directory.
  local _javaPath="$JAVA_HOME/bin/java"
  local _javacPath="$JAVA_HOME/bin/javac"
  [ ! -f "$_javaPath" ] && errorMessage "Unable to find java binary, ensure '$JAVA_HOME' is the home of a Java Development Kit version 6."
  [ ! -f "$_javacPath" ] && errorMessage "Unable to find javac binary, ensure '$JAVA_HOME' is the home of a Java Development Kit version 6."
  
  writeMessage "Found: $( "$_javaPath" -version 2>&1|head -n 1 )"
}

# usage: manageAntHome
function manageAntHome() {
  # Checks if environment variable ANT_HOME is defined.
  if [ -z "$ANT_HOME" ]; then
    # Checks if it is defined in configuration file.
    antHome=$( getConfigValue "$CONFIG_KEY.ant.home" ) || exit 100
    [ -z "$antHome" ] && errorMessage "You must either configure ANT_HOME environment variable or $CONFIG_KEY.ant.home configuration element."
    
    # Ensures it exists.
    [ ! -d "$antHome" ] && errorMessage "$CONFIG_KEY.ant.home defined $antHome which is not found."
    
    export ANT_HOME="$antHome"
  fi
  
  # Checks ant is available.
  local _antPath="$ANT_HOME/bin/ant"
  [ ! -f "$_antPath" ] && errorMessage "Unable to find ant binary, ensure '$ANT_HOME' is the home of a Java Development Kit version 6."
  
  writeMessage "Found: $( "$_antPath" -v 2>&1|head -n 1 )"
}
