#!/bin/bash
#
# Hemera - Intelligent System (https://sourceforge.net/projects/hemerais)
# Copyright (C) 2010 Bertrand Benoit <projettwk@users.sourceforge.net>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see http://www.gnu.org/licenses
# or write to the Free Software Foundation,Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301  USA
#
# Version: 1.0
# Description: provides lots of utilities functions.
#
# This script must NOT be directly called.

#########################
## Global configuration
# Cf. http://www.gnu.org/software/bash/manual/bashref.html#The-Shopt-Builtin
# Ensures respect to quoted arguments to the conditional command's =~ operator. 
shopt -s compat31

# Ensures installDir is defined.
[ -z "$installDir" ] && echo -e "This script must NOT be directly called. installDir variable not defined" >&2 && exit 1
source "$installDir/scripts/defineConstants.sh"

#########################
## Global variables
[ -z "$verbose" ] && verbose=0
[ -z "$showError" ] && showError=1 # Should NOT be modified but in some very specific case (like checkConfig)

# Defines default category if not already defined.
[ -z "$category" ] && category="general"


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

  # Checks if message must be shown on console.
  if [ -z "$noconsole" ] || [ $noconsole -eq 0 ]; then
    echo $echoOption "$messageTime  [$category]  $message" |tee -a "${h_logFile:-/tmp/hemera.log}"
  else
    echo $echoOption "$messageTime  [$category]  $message" >> "${h_logFile:-/tmp/hemera.log}"
  fi
}

# usage: info <message> [<0 or 1>]
# Shows message only if verbose is ON.
function info() {
  [ $verbose -eq 0 ] && return 0
  local message="$1"
  shift
  writeMessage "INFO: $message" $*
}

# usage: errorMessage <message> [<exit code>]
# Shows error message and exits.
function errorMessage() {
  local message="$1"
  messageTime=$(date +"%d/%m/%y %H:%M.%S")

  # Checks if message must be shown on console.
  if [ -z "$noconsole" ] || [ $noconsole -eq 0 ]; then
    echo -e "$messageTime  [$category]  \E[31m\E[4mERROR\E[0m: $message" |tee -a "${h_logFile:-/tmp/hemera.log}" >&2
  else
    echo -e "$messageTime  [$category]  \E[31m\E[4mERROR\E[0m: $message" >> "${h_logFile:-/tmp/hemera.log}"
  fi

  exit ${2:-$ERROR_DEFAULT}
}

# usage: updateStructure <dir path>
function updateStructure() {
  mkdir -p "$1" || errorMessage "Unable to create structure pieces (check permissions): $1" $ERROR_ENVIRONMENT
}

# usage: getLastLinesFromN <file path> <line begin>
function getLastLinesFromN() {
  local _source="$1" _lineBegin="$2"
  local _sourceLineCount=$( cat "$_source" |wc -l )

  # Returns the N last lines.
  tail -n $( expr $_sourceLineCount - $_lineBegin + 1 ) "$_source"
}

# usage: getLinesFromNToP <file path> <from line N> <line begin> <line end>
function getLinesFromNToP() {
  local _source="$1" _lineBegin="$2" _lineEnd="$3"
  local _sourceLineCount=$( cat "$_source" |wc -l )

  tail -n $( expr $_sourceLineCount - $_lineBegin + 1 ) "$_source" |head -n $( expr $_lineEnd - $_lineBegin + 1 )
}

# usage: checkBin <binary name/path>
function checkBin() {
  info "Checking binary: $1"
  which "$1" >/dev/null 2>&1 && return 0
  [ $showError -eq 0 ] && return 1
  errorMessage "Unable to find binary $1." $ERROR_CHECK_BIN
}

# usage: checkDataFile <data file path>
function checkDataFile() {
  info "Checking data file: $1"
  [ -f "$1" ] && return 0
  [ $showError -eq 0 ] && return 1
  errorMessage "Unable to find data file '$1'." $ERROR_CHECK_CONFIG
}

# usage: checkLSB
function checkLSB() {
  lsbFunctions="/lib/lsb/init-functions"
  [ -f "$lsbFunctions" ] || errorMessage "Unable to find LSB file $lsbFunctions. Please install it." $ERROR_ENVIRONMENT
  source "$lsbFunctions"
}


#########################
## Functions - PID & Process management

# usage: writePIDFile <pid file>
function writePIDFile() {
  local _pidFile="$1"
  [ -f "$_pidFile" ] && errorMessage "PID file '$_pidFile' already exists."
  echo "$$" > "$_pidFile"
  info "Written PID '$$' in file '$1'."
}

# usage: deletePIDFile <pid file>
function deletePIDFile() {
  info "Removing PID file '$1'"
  rm -f "$1"
}

# usage: getPIDFromFile <pid file>
function getPIDFromFile() {
  local _pidFile="$1"

  # Checks if PID file exists, otherwise regard process as NOT running.
  [ ! -f "$_pidFile" ] && info "PID file '$_pidFile' not found." && return 1

  # Gets PID from file, and ensures it is defined.
  local pidToCheck=$( head -n 1 "$1" )
  [ -z "$pidToCheck" ] && info "PID file '$_pidFile' empty." && return 1

  # Writes it.
  echo "$pidToCheck" && return 0
}

# usage: isRunningProcess <pid file> <process name>
function isRunningProcess() {
  local _pidFile="$1"
  local _processName=$( basename "$2" ) # Removes the path which can be different between each action

  # Checks if PID file exists, otherwise regard process as NOT running.
  pidToCheck=$( getPIDFromFile "$_pidFile" ) || return 1

  # Checks if a process with specified PID is running.
  info "Checking running process, PID=$pidToCheck, process=$_processName."
  [ $( ps h -p "$pidToCheck" |grep -E "$_processName($|[ \t])" |wc -l ) -eq 1 ] && return 0

  # It is not the case, informs and deletes the PID file.
  deletePIDFile "$_pidFile"
  info "process is dead but pid file exists. Deleted it."
  return 1
}

# usage: startProcess <pid file> <process name>
function startProcess() {
  local _pidFile="$1"
  shift
  local _processName="$1"

  ## Writes the PID file.
  writePIDFile "$_pidFile" || return 1

  ## If noconsole is not already defined, messages must only be written in log file (no more on console).
  [ -z "$noconsole" ] && export noconsole=1

  ## Executes the specified command -> such a way the command WILL have the PID written in the file.
  info "Starting background command: $*"
  exec $*
}

# usage: stopProcess <pid file> <process name>
function stopProcess() {
  local _pidFile="$1"
  local _processName="$2"

  # Gets the PID.
  pidToStop=$( getPIDFromFile "$_pidFile" ) || errorMessage "No PID found in file '$_pidFile'."

  # Requests stop.
  info "Requesting process stop, PID=$pidToStop, process=$_processName."
  kill "$pidToStop" || return 1

  # Waits until process stops, or timeout is reached.
  remainingTime=$PROCESS_STOP_TIMEOUT
  while [ $remainingTime -gt 0 ] && isRunningProcess "$_pidFile" "$_processName"; do
    # Waits 1 second.
    sleep 1
    let remainingTime--
  done

  # Checks if it is still running, otherwise deletes the PID file ands returns.
  ! isRunningProcess "$_pidFile" "$_processName" && deletePIDFile "$_pidFile" && return 0

  # Destroy the process.
  info "Killing process stop, PID=$pidToStop, process=$_processName."
  kill -9 "$pidToStop" || return 1
}

# usage: setUpKillChildTrap
function setUpKillChildTrap() {
  ## IMPORTANT: when the main process is stopped (or killed), all its child must be stopped too,
  ##  defines some trap to ensure that.
  # When this process receive an EXIT signal, kills all process of the group (including children, and main process).
  trap 'writeMessage "Killing all processes of the group of main process $_processName"; kill -s HUP 0' EXIT
}

# usage: manageDaemon <action> <name> <pid file> <process> [<logFile> <outputFile> <options>]
#   action can be: start, status, stop (and daemon, only for internal purposes)
#   logFile, outputFile and options are only needed if action is "start"
function manageDaemon() {
  local _action="$1" _name="$2" _pidFile="$3" _processName="$4"
  local _logFile="$5" _outputFile="$6" _options="$7"

  case "$_action" in
    daemon)
      # If the option is NOT the special one which activates last action "run"; setups trap ensuring
      # children process will be stopped in same time this main process is stopped, otherwise it will
      # setup when managing the run action.
      [[ "$_options" != "$DAEMON_SPECIAL_RUN_ACTION" ]] && setUpKillChildTrap

      # Starts the process.
      startProcess "$_pidFile" "$_processName" $_options
    ;;

    start)
      # Ensures it is not already running.
      isRunningProcess "$_pidFile" "$_processName" && writeMessage "$_name is already running." && return 0

      # Starts it, launching this script in daemon mode.
      h_logFile="$_logFile" "$0" -D >>"$_outputFile" 2>&1 &
      writeMessage "Launched $_name."
    ;;

    status)
      isRunningProcess "$_pidFile" "$_processName" && writeMessage "$_name is running." || writeMessage "$_name is stopped."
    ;;

    stop)
      # Ensures it is running.
      ! isRunningProcess "$_pidFile" "$_processName" && writeMessage "$_name is NOT running." && return 0

      # Stops the process.
      stopProcess "$_pidFile" "$_processName" || errorMessage "Unable to stop $_name."
      writeMessage "Stopped $_name."
    ;;

    run)
      ## If noconsole is not already defined, messages must only be written in log file (no more on console).
      [ -z "$noconsole" ] && export noconsole=1

      # Setups trap ensuring children process will be stopped in same time this main process is stopped.
      setUpKillChildTrap
    ;;

    [?])  return 1;;
  esac
}

# usage: daemonUsage <name>
function daemonUsage() {
  local _name="$1"
  echo -e "Usage: $0 -S||-T||-K [-hv]"
  echo -e "-S\tstart $_name daemon"
  echo -e "-T\tstatus $_name daemon"
  echo -e "-K\tstop $_name daemon"
  echo -e "-v\tactivate the verbose mode"
  echo -e "-h\tshow this usage"
  echo -e "\nYou must either start, status or stop the $_name daemon."

  exit $ERROR_USAGE
}

#########################
## Functions - configuration

# usage: getConfigValue <config key>
function getConfigValue() {
  # Checks if the key exists.
  [ $( grep -re "^$1=" "$h_configurationFile" |wc -l ) -eq 0 ] && errorMessage "$1 configuration key not found" $ERROR_CONFIG_VARIOUS

  # Gets the value (may be empty).
  grep -re "^$1=" "$h_configurationFile" |sed -e 's/^[^=]*=//;s/"//g;'
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
    javaHome=$( getConfigValue "$CONFIG_KEY.java.home" ) || exit $ERROR_CONFIG_VARIOUS
    [ -z "$javaHome" ] && errorMessage "You must either configure JAVA_HOME environment variable or $CONFIG_KEY.java.home configuration element." $ERROR_ENVIRONMENT

    # Ensures it exists.
    [ ! -d "$javaHome" ] && errorMessage "$CONFIG_KEY.java.home defined $javaHome which is not found." $ERROR_CONFIG_VARIOUS

    export JAVA_HOME="$javaHome"
  fi

  # Ensures it is a jdk home directory.
  local _javaPath="$JAVA_HOME/bin/java"
  local _javacPath="$JAVA_HOME/bin/javac"
  [ ! -f "$_javaPath" ] && errorMessage "Unable to find java binary, ensure '$JAVA_HOME' is the home of a Java Development Kit version 6." $ERROR_ENVIRONMENT
  [ ! -f "$_javacPath" ] && errorMessage "Unable to find javac binary, ensure '$JAVA_HOME' is the home of a Java Development Kit version 6." $ERROR_ENVIRONMENT

  writeMessage "Found: $( "$_javaPath" -version 2>&1|head -n 1 )"
}

# usage: manageAntHome
function manageAntHome() {
  # Checks if environment variable ANT_HOME is defined.
  if [ -z "$ANT_HOME" ]; then
    # Checks if it is defined in configuration file.
    antHome=$( getConfigValue "$CONFIG_KEY.ant.home" ) || exit $ERROR_CONFIG_VARIOUS
    [ -z "$antHome" ] && errorMessage "You must either configure ANT_HOME environment variable or $CONFIG_KEY.ant.home configuration element." $ERROR_ENVIRONMENT

    # Ensures it exists.
    [ ! -d "$antHome" ] && errorMessage "$CONFIG_KEY.ant.home defined $antHome which is not found." $ERROR_CONFIG_VARIOUS

    export ANT_HOME="$antHome"
  fi

  # Checks ant is available.
  local _antPath="$ANT_HOME/bin/ant"
  [ ! -f "$_antPath" ] && errorMessage "Unable to find ant binary, ensure '$ANT_HOME' is the home of a Java Development Kit version 6." $ERROR_ENVIRONMENT

  writeMessage "Found: $( "$_antPath" -v 2>&1|head -n 1 )"
}

# usage: launchJavaTool <class qualified name> <additional properties> <options>
function launchJavaTool() {
  local _jarFile="$h_libDir/hemera.jar"
  local _className="$1"
  local _additionalProperties="$2"
  local _options="$3"

  # Checks if verbose.
  [ $verbose -eq 0 ] && _additionalProperties="$_additionalProperties -Dhemera.log.noConsole=true"

  # Ensures jar file has been created.
  [ ! -f "$_jarFile" ] && errorMessage "You must build Hemera libraries before using $_className" $ERROR_ENVIRONMENT

  # N.B.: java tools output (standard and error) are append to the logfile; however, some error messages can
  #  be directly printed on output, so output are redirected to logfile too.

  # Launches the tool.
  "$JAVA_HOME/bin/java" -classpath "$_jarFile" \
    -Djava.system.class.loader=hemera.HemeraClassLoader \
    -Dhemera.property.file="$h_configurationFile" \
    -Dhemera.log.file="$h_logFile" $_additionalProperties \
    "$_className" \
    $_options >> "$h_logFile" 2>&1
}
