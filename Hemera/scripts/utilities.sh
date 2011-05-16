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

# usage: warning <message>
# Shows warning message.
function warning() {
  local message="$1"
  messageTime=$(date +"%d/%m/%y %H:%M.%S")

  # Checks if message must be shown on console.
  if [ -z "$noconsole" ] || [ $noconsole -eq 0 ]; then
    echo -e "$messageTime  [$category]  \E[31m\E[4mWARNING\E[0m: $message" |tee -a "${h_logFile:-/tmp/hemera.log}" >&2
  else
    echo -e "$messageTime  [$category]  \E[31m\E[4mWARNING\E[0m: $message" >> "${h_logFile:-/tmp/hemera.log}"
  fi
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

  cat -n "$_source" |awk "\$1 >= $_lineBegin {print}" |sed -e 's/^[ \t]*[0-9][0-9]*[ \t]*//'
}

# usage: getLinesFromNToP <file path> <from line N> <line begin> <line end>
function getLinesFromNToP() {
  local _source="$1" _lineBegin="$2" _lineEnd="$3"
  local _sourceLineCount=$( cat "$_source" |wc -l )

  tail -n $( expr $_sourceLineCount - $_lineBegin + 1 ) "$_source" |head -n $( expr $_lineEnd - $_lineBegin + 1 )
}

# usage: checkGNUWhich
# Ensures "which" is a GNU which.
function checkGNUWhich() {
  [ $( LANG=C which --version 2>&1|head -n 1 |grep -w "GNU" |wc -l ) -eq 1 ]
}

# usage: checkEnvironment
function checkEnvironment() {
  checkGNUWhich || errorMessage "GNU version of which not found. Please install it." $ERROR_ENVIRONMENT
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

# usage: isEmptyDirectory <path>
function isEmptyDirectory()
{
  [ $( ls -1 "$1" |wc -l ) -eq 0 ]
}

# usage: cleanNotManagedInput
function cleanNotManagedInput() {
  info "Cleaning NOT managed input (new and current)"
  rm -f "$h_newInputDir"/* "$h_curInputDir"/* >/dev/null || exit $ERROR_ENVIRONMENT
}

# usage: waitUntilAllInputManaged [<timeout>]
# Default timeout is 2 minutes.
function waitUntilAllInputManaged() {
  local _remainingTime=${1:-120}
  info "Waiting until all input are managed (timeout: $_remainingTime seconds)"
  while ! isEmptyDirectory "$h_newInputDir" || ! isEmptyDirectory "$h_curInputDir"; do
    [ $_remainingTime -eq 0 ] && break
    sleep 1
    let _remainingTime--
  done
}

# usage: matchesOneOf <patterns> <element to check>
function matchesOneOf() {
  local _patterns="$1" _element="$2"

  for pattern in $_patterns; do
    [[ "$_element" =~ "$pattern" ]] && return 0
  done

  return 1
}

# usage: extractI18Nelement <locale file> <destination file>
function extractI18Nelement() {
  local _localeFile="$1" _destFile="$2"
  grep -re "^[ \t]*[^#]" "$_localeFile" |sort > "$_destFile"
}

#########################
## Functions - Recognized Commands mode
# usage: initRecoCmdMode
# Creates hemera mode file with normal mode.
function initRecoCmdMode() {
  updateRecoCmdMode "$H_RECO_CMD_MODE_NORMAL_I18N"
}

# usage: updateRecoCmdMode <i18n mode>
function updateRecoCmdMode() {
  local _newModei18N="$1"

  # Defines the internal mode corresponding to this i18n mode (usually provided by speech recognition).
  local _modeIndex=0
  for availableMode in ${H_SUPPORTED_RECO_CMD_MODES_I18N[*]}; do
    # Checks if this is the specified mode.
    if [ "$_newModei18N" = "$availableMode" ]; then
      # It is the case, writes the corresponding internal mode in the mode file.
      echo "${H_SUPPORTED_RECO_CMD_MODES[$_modeIndex]}" > "$h_recoCmdModeFile"
      return 0
    fi

    let _modeIndex++
  done

  # No corresponding internal mode has been found, it is fatal.
  # It should NEVER happen because mode must have been checked before this call.
  errorMessage "Unable to find corresponding internal mode of I18N mode '$_newModei18N'" $ERROR_ENVIRONMENT
}

# usage: getRecoCmdMode
# Returns the recognized commands mode.
function getRecoCmdMode() {
  # Ensures the mode file exists.
  [ ! -f "$h_recoCmdModeFile" ] && errorMessage "Unable to find Hemera recognized command mode file '$h_recoCmdModeFile'" $ERROR_ENVIRONMENT
  cat "$h_recoCmdModeFile"
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
  kill -s TERM "$pidToStop" || return 1

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
  kill -s KILL "$pidToStop" || return 1
}

# usage: killChildProcesses <pid> [1]
# 1: toggle defining is it the top hierarchy proces.
function killChildProcesses() {
  local _pid=$1 _topProcess=${2:-0}

  # Manages PID of each child process of THIS process.
  for childProcessPid in $( ps -o pid --no-headers --ppid $_pid ); do
    # Ensures the child process still exists; it won't be the case of the last launched ps allowing to
    #  get child process ...
    $( ps -p $childProcessPid --no-headers >/dev/null ) && killChildProcesses "$childProcessPid"
  done

  # Kills the child process if not main one.
  [ $_topProcess -eq 0 ] && kill -s HUP $_pid 
}

# usage: setUpKillChildTrap <process name>
function setUpKillChildTrap() {
  export TRAP_processName="$1"

  ## IMPORTANT: when the main process is stopped (or killed), all its child must be stopped too,
  ##  defines some trap to ensure that.
  # When this process receive an EXIT signal, kills all its child processes.
  # N.B.: old system, killing all process of the same process group was causing error like "broken pipe" ...
  trap 'writeMessage "Killing all processes of the group of main process $TRAP_processName"; killChildProcesses $$ 1; exit 0' EXIT
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
      [[ "$_options" != "$DAEMON_SPECIAL_RUN_ACTION" ]] && setUpKillChildTrap "$_processName"

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
      setUpKillChildTrap "$_processName"
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
  # N.B.: in case there is several, takes only the last one (interesting when there is several definition in configuration file).
  grep -re "^$1=" "$h_configurationFile" |sed -e 's/^[^=]*=//;s/"//g;' |tail -n 1
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
## Functions - uptime

# usage: initializeUptime
function initializeStartTime() {
  date +'%s' > "$h_startTime"
}

# usage: getUptime
function getUptime() {
  [ ! -f "$h_startTime" ] && echo "not started" && exit 0
  
  local _currentTime=$( date +'%s' )
  local _startTime=$( cat "$h_startTime" )
  local _uptime=$( expr $_currentTime - $_startTime )

  printf "%02dd %02dh:%02dm.%02ds" $(($_uptime/86400)) $(($_uptime%86400/3600)) $(($_uptime%3600/60)) $(($_uptime%60))
}

#########################
## Functions - commands

# usage: initializeCommandMap
function initializeCommandMap() {
  # Removes the potential existing list file.
  rm -f "$h_commandMap"

  # For each available commands.
  for commandRaw in $( find "$h_coreDir/command" -maxdepth 1 -type f ! -name "*~" ! -name "*.txt" |sort |sed -e 's/[ \t]/£/g;' ); do
    local _command=$( echo "$commandRaw" |sed -e 's/£/ /g;' )
    local _commandName=$( basename "$_command" )
    
    # Extracts keyword.
    local _keyword=$( head -n 30 "$_command" |grep "^#.Keyword:" |sed -e 's/^#.Keyword:[ \t]*//g;s/[ \t]*$//g;' )
    [ -z "$_keyword" ] && warning "The command '$_commandName' doesn't seem to respect format. It will be ignored." && continue

    # Updates command map file.
    for localizedName in $( grep -re "$_keyword"_"PATTERN_I18N" "$h_i18nFile" |sed -e 's/^[^(]*(//g;s/).*$//g;s/"//g;' ); do
      echo "$localizedName=$_command" >> "$h_commandMap"
    done
  done
}

# usage: getMappedCommand <speech recognition result command>
# <speech recognition result command>: 1 word corresponding to speeched command
# returns the mapped command script if any, empty string otherwise.
function getMappedCommand() {
  local _commandName="$1"

  # Ensures map file exists.
  [ ! -f "$h_commandMap" ] && warning "The command map file has not been initialized." && return 1

  # Attempts to get mapped command script.
  echo $( grep "^$_commandName=" "$h_commandMap" |sed -e 's/^[^=]*=//g;' )
}

#########################
## Functions - source code management
# usage: manageJavaHome
# Ensures JAVA environment is ok, and ensures JAVA_HOME is defined.
function manageJavaHome() {
  # Checks if environment variable JAVA_HOME is defined.
  if [ -z "$JAVA_HOME" ]; then
    # Checks if it is defined in configuration file.
    javaHome=$( getConfigValue "environment.java.home" ) || exit $ERROR_CONFIG_VARIOUS
    [ -z "$javaHome" ] && errorMessage "You must either configure JAVA_HOME environment variable or $CONFIG_KEY.java.home configuration element." $ERROR_ENVIRONMENT

    # Ensures it exists.
    [ ! -d "$javaHome" ] && errorMessage "environment.java.home defined $javaHome which is not found." $ERROR_CONFIG_VARIOUS

    export JAVA_HOME="$javaHome"
  fi

  # Ensures it is a jdk home directory.
  local _javaPath="$JAVA_HOME/bin/java"
  local _javacPath="$JAVA_HOME/bin/javac"
  [ ! -f "$_javaPath" ] && errorMessage "Unable to find java binary, ensure '$JAVA_HOME' is the home of a Java Development Kit version 6." $ERROR_ENVIRONMENT
  [ ! -f "$_javacPath" ] && errorMessage "Unable to find javac binary, ensure '$JAVA_HOME' is the home of a Java Development Kit version 6." $ERROR_ENVIRONMENT

  writeMessage "Found: $( "$_javaPath" -version 2>&1|head -n 2| sed -e 's/$/ [/;' |tr -d '\n' |sed -e 's/..$/]/' )"
}

# usage: manageAntHome
# Ensures ANT environment is ok, and ensures ANT_HOME is defined.
function manageAntHome() {
  # Checks if environment variable ANT_HOME is defined.
  if [ -z "$ANT_HOME" ]; then
    # Checks if it is defined in configuration file.
    antHome=$( getConfigValue "environment.ant.home" ) || exit $ERROR_CONFIG_VARIOUS
    [ -z "$antHome" ] && errorMessage "You must either configure ANT_HOME environment variable or $CONFIG_KEY.ant.home configuration element." $ERROR_ENVIRONMENT

    # Ensures it exists.
    [ ! -d "$antHome" ] && errorMessage "environment.ant.home defined $antHome which is not found." $ERROR_CONFIG_VARIOUS

    export ANT_HOME="$antHome"
  fi

  # Checks ant is available.
  local _antPath="$ANT_HOME/bin/ant"
  [ ! -f "$_antPath" ] && errorMessage "Unable to find ant binary, ensure '$ANT_HOME' is the home of a Java Development Kit version 6." $ERROR_ENVIRONMENT

  writeMessage "Found: $( "$_antPath" -v 2>&1|head -n 1 )"
}

# usage: manageTomcatHome
# Ensures Tomcat environment is ok, and defines h_tomcatDir.
function manageTomcatHome() {
  local tomcatDir="$h_tpDir/webServices/bin/tomcat"
  [ ! -d "$tomcatDir" ] && errorMessage "Apache Tomcat '$tomcatDir' not found. You must either disable Tomcat activation (hemera.run.activation.tomcat), or install it/create a symbolic link." $ERROR_CONFIG_VARIOUS
  export h_tomcatDir="$tomcatDir"

  # Checks the Tomcat version.
  local _version="Apache Tomcat Version [unknown]"
  if [ -f "$tomcatDir/RELEASE-NOTES" ]; then
    _version=$( head -n 30 "$tomcatDir/RELEASE-NOTES" |grep "Apache Tomcat Version" |sed -e 's/^[ \t][ \t]*//g;' )
  elif [ -x "/bin/rpms" ]; then
    _version="Apache Tomcat Version "$( cd -P "$tomcatDir"; /bin/rpm -qf "$PWD" |sed -e 's/^[^-]*-\([0-9.]*\)-.*$/\1/' )
  fi
  
  writeMessage "Found: $_version"
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
