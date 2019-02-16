#!/bin/bash
#
# Author: Bertrand Benoit <mailto:contact@bertrand-benoit.net>
# Version: 2.0
#
# Description: Common utilities for all Bsquare's scripts (available on GitHub), and for your own scripts.
# Repositories: https://github.com/bertrand-benoit
#
# Optional variables you can define before sourcing this file:
#  ROOT_DIR           <path>  root directory to consider when performing various check
#  TMP_DIR            <path>  temporary directory where various dump files will be created
#  PID_DIR            <path>  directory where PID files will be created to manage daemon feature
#  CONFIG_FILE        <path>  path of configuration file to consider
#  GLOBAL_CONFIG_FILE <path>  path of GLOBAL configuration file to consider (configuration element will be checked in this one, if NOT found in the configuration file)
#
#  DEBUG_UTILITIES              0|1  activate debug message (not recommended in production)
#  VERBOSE                      0|1  activate info message (not recommended in production)
#  CATEGORY                 <string> the category which prepends all messages
#  LOG_CONSOLE_OFF              0|1  disable message output on console
#  LOG_FILE                   <path> path of the log file
#  LOG_FILE_APPEND_MODE         0|1  activate append mode, instead of override one
#  MODE_CHECK_CONFIG_AND_QUIT   0|1  check ALL configuration and then quit (useful to check all the configuration you want, +/- like a dry run)
#
# N.B.: when using checkAndSetConfig function (see usage), you can get back the corresponding configuration in LAST_READ_CONFIG variable
#        if it has NOT been found, it is set to $CONFIG_NOT_FOUND.

#########################
## Global configuration
# Cf. http://www.gnu.org/software/bash/manual/bashref.html#The-Shopt-Builtin
# Ensures respect to quoted arguments to the conditional command's =~ operator.
shopt -s compat31

# Used variables MUST be initialized.
set -o nounset
# Traces error in function & co.
set -o errtrace

# Dumps function call in case of error, or when exiting with something else than status 0.
trap '_status=$?; dumpFuncCall $_status' ERR
trap '_status=$?; [ $_status -ne 0 ] && dumpFuncCall $_status' EXIT

#########################
## Constants
declare -r DEFAULT_ROOT_DIR="${DEFAULT_ROOT_DIR:-${HOME:-/home/$( whoami )}}"
declare -r DEFAULT_TMP_DIR="${TMP_DIR:-/tmp/$( date +'%Y-%m-%d-%H-%M-%S' )-$( basename "$0" )}"
declare -r DEFAULT_LOG_FILE="${DEFAULT_LOG_FILE:-$DEFAULT_TMP_DIR/logFile.log}"
declare -r DEFAULT_TIME_FILE="$DEFAULT_TMP_DIR/timeFile"

declare -r DEFAULT_CONFIG_FILE="$DEFAULT_ROOT_DIR/.config/$( basename "$0" ).conf"
declare -r DEFAULT_GLOBAL_CONFIG_FILE="/etc/$( basename "$0" ).conf"
declare -r DEFAULT_PID_DIR="$DEFAULT_TMP_DIR/_pids"

mkdir -p "$DEFAULT_PID_DIR"

# Log Levels.
declare -r LOG_LEVEL_INFO=1
declare -r LOG_LEVEL_MESSAGE=2
declare -r LOG_LEVEL_WARNING=3
declare -r LOG_LEVEL_ERROR=4

# Configuration element types.
declare -r CONFIG_NOT_FOUND="CONFIG NOT FOUND"
declare -r CONFIG_TYPE_PATH=1
declare -r CONFIG_TYPE_OPTION=2
declare -r CONFIG_TYPE_BIN=3
declare -r CONFIG_TYPE_DATA=4

## Error code
# Default error message code.
declare -r ERROR_DEFAULT=101

# Error code after showing usage.
declare -r ERROR_USAGE=102

# Command line syntax not respected.
declare -r ERROR_BAD_CLI=103

# Bad/incomplete environment, like:
#  - missing Java or Ant
#  - bad user
#  - permission issue (e.g. while updating structure)
declare -r ERROR_ENVIRONMENT=104

# Invalid configuration, or path definition.
declare -r ERROR_CONFIG_VARIOUS=105
declare -r ERROR_CONFIG_PATH=106

# Binary or data configured file not found.
declare -r ERROR_CHECK_BIN=107
declare -r ERROR_CHECK_CONFIG=108

# Bad/unsupported mode.
declare -r ERROR_MODE=109

# External tool fault (e.g. curl, wget ...).
declare -r ERROR_EXTERNAL_TOOL=110

# Timeout (in seconds) when stopping process, before killing it.
declare -r PROCESS_STOP_TIMEOUT=10
declare -r DAEMON_SPECIAL_RUN_ACTION="-R"

#########################
## Global variables
DEBUG_UTILITIES=${DEBUG_UTILITIES:-0}
VERBOSE=${VERBOSE:-$DEBUG_UTILITIES}
# special toggle defining if system must quit after configuration check (activate when using -X option of scripts)
MODE_CHECK_CONFIG_AND_QUIT=${MODE_CHECK_CONFIG_AND_QUIT:-0}
# Defines default CATEGORY if not already defined.
CATEGORY=${CATEGORY:-general}
# By default, system logs messages on console.
LOG_CONSOLE_OFF=${LOG_CONSOLE_OFF:-0}
# Initializes temporary log file with temporary value.
LOG_FILE=${LOG_FILE:-$DEFAULT_LOG_FILE}
# By default, each component has a specific log file
#  (LOG_FILE_APPEND_MODE allows to define if caller script can continue to log in same file).
LOG_FILE_APPEND_MODE=${LOG_FILE_APPEND_MODE:-0}

# Initializes environment variables if not already the case.
ANT_HOME=${ANT_HOME:-}
JAVA_HOME=${JAVA_HOME:-}
LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}

#########################
## Functions - various

# usage: dumpFuncCall <exit status>
function dumpFuncCall() {
  # Defines count of function names.
  local _exitStatus="${1:-?}" _funcNameCount=${#FUNCNAME[@]}

  # Ignores following exit status:
  #  ERROR_USAGE: used in usage method (error will have already been shown)
  #  ERROR_BAD_CLI: bad CLI use (error will have already been shown)
  #  ERROR_INPUT_PROCESS: an error message will be said
  #  ERROR_CHECK_BIN an error message will be shown
  #  ERROR_CHECK_CONFIG an error message will be shown
  [ "$_exitStatus" -eq $ERROR_USAGE ] && return 0
  [ "$_exitStatus" -eq $ERROR_BAD_CLI ] && return 0
  [ "$_exitStatus" -eq $ERROR_CHECK_BIN ] && return 0
  [ "$_exitStatus" -eq $ERROR_CHECK_CONFIG ] && return 0
  [ "$_exitStatus" -eq $ERROR_CONFIG_VARIOUS ] && return 0
  [ "$_exitStatus" -eq $ERROR_CONFIG_PATH ] && return 0

  # Ignores the call if the system is currently in _doWriteMessage, in which
  #  case the exit status has been "manually" executed after error message shown.
  [ "${FUNCNAME[1]}" = "_doWriteMessage" ] && return 0

  # Prepares message begin.
  message="Status $_exitStatus at "

  # Disables call when it corresponds to the warning exit status of a previous call to this function.
  [ "$_funcNameCount" -le 2 ] && warning "$message${FUNCNAME[1]}:${BASH_LINENO[1]}" && return 0

  # Starts to 1 to avoid THIS function name, and stops before the last one to avoid "main".
  for index in $( eval echo "{$((_funcNameCount-2))..1}" ); do
    [ "$index" -lt $((_funcNameCount-2)) ] && message="$message->"
    message="$message${BASH_SOURCE[$index]}#${FUNCNAME[$index]}:${BASH_LINENO[$index]}"
  done

  warning "$message"
  return 0
}

# usage: getVersion <file path>
# This method returns the more recent version of the given ChangeLog/NEWS file path.
function getVersion() {
    local _newsFile="$1"

    # Lookup the version in the NEWS file (which did not exist in version 0.1)
    [ ! -f "$_newsFile" ] && echo "0.1.0" && return 0

    # Extracts the version.
    grep "version [0-9]" "$_newsFile" |head -n 1 |sed -e 's/^.*version[ \t]\([0-9][0-9.]*\)[ \t].*$/\1/;s/^.*version[ \t]\([0-9][0-9.]*\)$/\1/;'
}

# usage: getDetailedVersion <Major Version> <installation directory>
function getDetailedVersion() {
  local _majorVersion="$1" _installDir="$2"

  # General version is given by the specified $_majorVersion.
  # Before all, trying to get precise version in case of source code version.
  lastCommit=$( cd "$_installDir"; LANG=C git log -1 --abbrev-commit --date=short 2>&1 |grep -wE "commit|Date" |sed -e 's/Date:. / of/' |tr -d '\n' )
  [ -n "$lastCommit" ] && lastCommit=" ($lastCommit)"

  # Prints the general version and the potential precise version (will be empty if not defined).
  echo "$_majorVersion$lastCommit"
}

# usage: isVersionGreater <version 1> <version 2>
# Version syntax must be digits separated by dot (e.g. 0.1.0).
function isVersionGreater() {
  # Safeguard - ensures syntax is respected.
  [ "$( echo "$1" |grep -ce "^[0-9][0-9.]*$" )" -eq 1 ] || errorMessage "Unable to compare version because version '$1' does not fit the syntax (digits separated by dot)" $ERROR_ENVIRONMENT
  [ "$( echo "$2" |grep -ce "^[0-9][0-9.]*$" )" -eq 1 ] || errorMessage "Unable to compare version because version '$2' does not fit the syntax (digits separated by dot)" $ERROR_ENVIRONMENT

  # Checks if the version are equals (in which case the first one is NOT greater than the second).
  [[ "$1" == "$2" ]] && return 1

  # Defines arrays with specified versions.
  local _v1Array=( ${1//./ } )
  local _v2Array=( ${2//./ } )

  # Lookups version element until they are not the same.
  index=0
  while [ "${_v1Array[$index]}" -eq "${_v2Array[$index]}" ]; do
    let index++

    # Ensures there is another element for each version.
    [ -z "${_v1Array[$index]:-}" ] && v1End=1 || v1End=0
    [ -z "${_v2Array[$index]:-}" ] && v2End=1 || v2End=0

    # Continues on next iteration if NONE is empty.
    [ $v1End -eq 0 ] && [ $v2End -eq 0 ] && continue

    # If the two versions have been fully managed, they are equals (so the first is NOT greater).
    [ $v1End -eq 1 ] && [ $v2End -eq 1 ] && return 1

    # if the first version has not been fully managed, it is greater
    #  than the second (there is still version information), and vice versa.
    [ $v1End -eq 0 ] && return 0 || return 1
  done

  # returns the comparaison of the element with 'index'.
  [ "${_v1Array[$index]}" -gt "${_v2Array[$index]}" ]
}

# usage: _doWriteMessage <level> <message> <newline> <exit code>
# <level>: LOG_LEVEL_INFO|LOG_LEVEL_MESSAGE|LOG_LEVEL_WARNING|LOG_LEVEL_ERROR
# <message>: the message to show
# <newline>: 0 to stay on same line, 1 to break line
# <exit code>: the exit code (usually for ERROR message), -1 for NO exit.
#
# N.B.: you should NEVER call this function directly.
function _doWriteMessage() {
  local _level="$1" _message="$2" _newLine="${3:-1}" _exitCode="${4:--1}"

  # Safe-guard on numeric values (if this function is directly called).
  [ "$( echo "$_newLine" |grep -ce "^[0-9]$" )" -ne 1 ] && _newLine="1"
  [ "$( echo "$_exitCode" |grep -ce "^-*[0-9]$" )" -ne 1 ] && _exitCode="-1"

  # Does nothing if INFO message and NOT VERBOSE.
  [ "$VERBOSE" -eq 0 ] && [ "$_level" = "$LOG_LEVEL_INFO" ] && return 0

  local _messageTime=$(date +"%d/%m/%y %H:%M.%S")

  # Manages level.
  _messagePrefix=""
  [ "$_level" = "$LOG_LEVEL_INFO" ] && _messagePrefix="INFO: "
  [ "$_level" = "$LOG_LEVEL_WARNING" ] && _messagePrefix="\E[31m\E[4mWARNING\E[0m: "
  [ "$_level" = "$LOG_LEVEL_ERROR" ] && _messagePrefix="\E[31m\E[4mERROR\E[0m: "

  [ "$_newLine" -eq 0 ] && printMessageEnd="" || printMessageEnd="\n"

  # Checks if message must be shown on console.
  if [ "$LOG_CONSOLE_OFF" -eq 0 ]; then
    printf "%-17s %-15s $_messagePrefix%b$printMessageEnd" "$_messageTime" "[$CATEGORY]" "$_message" |tee -a "$LOG_FILE"
  else
    printf "%-17s %-15s $_messagePrefix%b$printMessageEnd" "$_messageTime" "[$CATEGORY]" "$_message" >> "$LOG_FILE"
  fi

  # Manages exit if needed.
  [ "$_exitCode" -eq -1 ] && return 0
  exit "$_exitCode"
}

# usage: writeMessage <message>
# Shows the message, and moves to next line.
function writeMessage() {
  _doWriteMessage $LOG_LEVEL_MESSAGE "$1" "${2:-1}" -1
}

# usage: writeMessageSL <message>
# Shows the message, and stays to same line.
function writeMessageSL() {
  _doWriteMessage $LOG_LEVEL_MESSAGE "$1" 0 -1
}

# usage: info <message> [<0 or 1>]
# Shows message only if $VERBOSE is ON.
# Stays on the same line of "0" has been specified
function info() {
  _doWriteMessage $LOG_LEVEL_INFO "$1" "${2:-1}"
}

# usage: warning <message> [<0 or 1>]
# Shows warning message.
# Stays on the same line of "0" has been specified
function warning() {
  _doWriteMessage $LOG_LEVEL_WARNING "$1" "${2:-1}" >&2
}

# usage: errorMessage <message> [<exit code>]
# Shows error message and exits.
function errorMessage() {
  _doWriteMessage $LOG_LEVEL_ERROR "$1" 1 "${2:-$ERROR_DEFAULT}" >&2
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

  tail -n $((_sourceLineCount - _lineBegin + 1)) "$_source" |head -n $((_lineEnd - _lineBegin + 1))
}

# usage: checkGNUWhich
# Ensures "which" is a GNU which.
function checkGNUWhich() {
  [ "$( LANG=C which --version 2>&1|head -n 1 |grep -cw "GNU" )" -eq 1 ]
}

# usage: checkEnvironment
function checkEnvironment() {
  checkGNUWhich || errorMessage "GNU version of which not found. Please install it." $ERROR_ENVIRONMENT
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
  [ "$( ls -1 "$1" |wc -l )" -eq 0 ]
}

# usage: matchesOneOf <patterns> <element to check>
function matchesOneOf() {
  local _patterns="$1" _element="$2"

  for pattern in $_patterns; do
    [[ "$_element" =~ "$pattern" ]] && return 0
  done

  return 1
}

# usage: extractI18Nelement <i18n file> <destination file>
function extractI18Nelement() {
  local _i18nFile="$1" _destFile="$2"
  grep -e "^[ \t]*[^#]" "$_i18nFile" |sort > "$_destFile"
}

# usage: checkOSLocale
function checkOSLocale() {
  [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && info "Checking LANG environment variable ... "

  # Checks LANG is defined with UTF-8.
  if [ "$( echo "$LANG" |grep -ci "[.]utf[-]*8" )" -eq 0 ] ; then
      # It is a fatal error but in 'MODE_CHECK_CONFIG_AND_QUIT' mode.
      warning "You must update your LANG environment variable to use the UTF-8 charmaps ('${LANG:-NONE}' detected). Until then system will attempt using en_US.UTF-8."

      export LANG="en_US.UTF-8"
  fi

  # Ensures defined LANG is avaulable on the OS.
  if [ "$( locale -a 2>/dev/null |grep -ci $LANG )" -eq 0 ] && [ "$( locale -a 2>/dev/null |grep -c "$( echo $LANG |sed -e 's/UTF[-]*8/utf8/' )" )" -eq 0 ]; then
    # It is a fatal error but in 'MODE_CHECK_CONFIG_AND_QUIT' mode.
    warning "Although the current OS locale '$LANG' defines to use the UTF-8 charmaps, it is not available (checked with 'locale -a'). You must install it or update your LANG environment variable. Until then system will attempt using en_US.UTF-8."

    export LANG="en_US.UTF-8"
  fi

  return 0
}

# usage: getURLContents <url> <destination file>
function getURLContents() {
  info "Getting contents of URL '$1'"
  ! wget --user-agent="Mozilla/Firefox 3.6" -q "$1" -O "$2" && warning "Error while getting contents of URL '$1'" && return 1
  info "Got contents of URL '$1' with success"
  return 0
}

#########################
## Functions - PID & Process management

# usage: writePIDFile <pid file> <process name>
function writePIDFile() {
  local _pidFile="$1" _processName="$2"
  [ -f "$_pidFile" ] && errorMessage "PID file '$_pidFile' already exists."
  echo "processName=$_processName" > "$_pidFile"
  echo "pid=$$" >> "$_pidFile"
  info "Written PID '$$' of process '$_processName' in file '$1'."
}

# usage: deletePIDFile <pid file>
function deletePIDFile() {
  info "Removing PID file '$1'"
  rm -f "$1"
}

# usage: extractProcessNameFromFile <pid file>
function extractProcessNameFromFile() {
  grep -e "^processName=" "$1" |head -n 1 |sed -e 's/^[^=]*=//'
}

# usage: getPIDFromFile <pid file>
function extractPIDFromFile() {
  grep -e "^pid=" "$1" |head -n 1 |sed -e 's/^pid=\([0-9][0-9]*\)$/\1/'
}

# usage: getPIDFromFile <pid file>
function getPIDFromFile() {
  local _pidFile="$1"

  # Checks if PID file exists, otherwise regard process as NOT running.
  [ ! -f "$_pidFile" ] && info "PID file '$_pidFile' not found." && return 1

  # Gets PID from file, and ensures it is defined.
  local pidToCheck=$( grep -e "^pid=" "$_pidFile" |head -n 1 |sed -e 's/^pid=\([0-9][0-9]*\)$/\1/' )
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

  # Special hacks to help users. Some application uses symbolic links, and so running process name
  #  won't be the same than launched process name. For instance it is the case with SoX (in particular
  #  when source code has been compiled).
  # This is the list of "synonyms":
  #  - sox/play/rec/lt-sox
  [ "$_processName" = "play" ] && _processName="$_processName|sox"
  [ "$_processName" = "rec" ] && _processName="$_processName|sox"

  # Checks if a process with specified PID is running.
  info "Checking running process, PID=$pidToCheck, process=$_processName."
  [ "$( ps h -p "$pidToCheck" |grep -cE "$_processName($|[ \t])" )" -eq 1 ] && return 0

  # It is not the case, informs and deletes the PID file.
  deletePIDFile "$_pidFile"
  info "process is dead but pid file exists. Deleted it."
  return 1
}

# usage: checkAllPIDFiles
# Checks all existing PID files, checks if corresponding process are still running,
#  and deletes PID files if it is not the case.
function checkAllProcessFromPIDFiles() {
  info "Check any existing PID file (and clean if corresponding process is no more running)."
  # For any existing PID file.
  for pidFile in $( find "${PID_DIR:-$DEFAULT_PID_DIR}" -type f ); do
    processName=$( extractProcessNameFromFile "$pidFile" )

    # Checks if there is still a process with this name and this PID,
    #  if it is not the case, the PID file will be removed.
    isRunningProcess "$pidFile" "$processName"
  done
}

# usage: startProcess <pid file> <process name>
function startProcess() {
  local _pidFile="$1"
  shift
  local _processName="$1"

  ## Writes the PID file.
  writePIDFile "$_pidFile" "$_processName" || return 1

  ## If LOG_CONSOLE_OFF is not already defined, messages must only be written in log file (no more on console).
  [ -z "$LOG_CONSOLE_OFF" ] && export LOG_CONSOLE_OFF=1

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
# 1: toggle defining is it the top hierarchy process.
function killChildProcesses() {
  local _pid=$1 _topProcess=${2:-0}

  # Manages PID of each child process of THIS process.
  for childProcessPid in $( ps -o pid --no-headers --ppid "$_pid" ); do
    # Ensures the child process still exists; it won't be the case of the last launched ps allowing to
    #  get child process ...
    $( ps -p "$childProcessPid" --no-headers >/dev/null ) && killChildProcesses "$childProcessPid"
  done

  # Kills the child process if not main one.
  [ "$_topProcess" -eq 0 ] && kill -s HUP "$_pid"
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
      LOG_FILE="$_logFile" LOG_CONSOLE_OFF=${LOG_CONSOLE_OFF:-1} "$0" -D >>"$_outputFile" &
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
      ## If LOG_CONSOLE_OFF is not already defined, messages must only be written in log file (no more on console).
      [ -z "$LOG_CONSOLE_OFF" ] && export LOG_CONSOLE_OFF=1

      # Setups trap ensuring children process will be stopped in same time this main process is stopped.
      setUpKillChildTrap "$_processName"
    ;;

    [?])  return 1;;
  esac
}

# usage: daemonUsage <name>
function daemonUsage() {
  local _name="$1"
  echo -e "Usage: $0 -S||-T||-K||-X [-hv]"
  echo -e "-S\tstart $_name daemon"
  echo -e "-T\tstatus $_name daemon"
  echo -e "-K\tstop $_name daemon"
  echo -e "-X\tcheck configuration and quit"
  echo -e "-v\tactivate the verbose mode"
  echo -e "-h\tshow this usage"
  echo -e "\nYou must either start, status or stop the $_name daemon."

  exit $ERROR_USAGE
}

#########################
## Functions - configuration

# usage: isRootUser
function isRootUser() {
  [[ "$( whoami )" == "root" ]]
}

# usage: pruneSlash <path>
# Prunes ending slash, prunes useless slash in path, and returns purified path.
function pruneSlash() {
  # Unable to perform equivalent instruction only in GNU/Bash (because there is no way to 'say' 'end of line'):
  #  - ${HOME/%\//} -> removes only ONE ending slash if any
  #  - ${HOME/%\/\/*/} -> removes everything even if there is path pieces after last slash.
  echo "$1" |sed -e 's/\/\/*/\//g;s/^\(.[^\/][^\/]*\)\/\/*$/\1/'
}

# usage: checkConfigValue <configuration file> <config key>
function checkConfigValue() {
  local _configFile="$1" _configKey="$2"
  # Ensures configuration file exists ('user' one does not exist for root user;
  #  and 'global' configuration file does not exists for only-standard user installation.
  if [ ! -f "$_configFile" ]; then
    # IMPORTANT: be careful not to print something in the standard output or it would break the checkAndSetConfig feature.
    [ "$DEBUG_UTILITIES" -eq 1 ] && printf "Configuration file '$_configFile' not found ... " >&2
    return 1
  fi
  [ "$( grep -ce "^$_configKey=" "$_configFile" 2>/dev/null )" -gt 0 ]
}

# usage: getConfigValue <config key>
function getConfigValue() {
  local _configKey="$1"

  # Checks in use configuration file.
  configFileToRead="${CONFIG_FILE:-$DEFAULT_CONFIG_FILE}"
  if ! checkConfigValue "$configFileToRead" "$_configKey"; then
    # Checks in global configuration file.
    configFileToRead="${GLOBAL_CONFIG_FILE:-$DEFAULT_GLOBAL_CONFIG_FILE}"
    if ! checkConfigValue "$configFileToRead" "$_configKey"; then
      # Prints error message (and exit) only if NOT in "check config and quit" mode.
      [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && errorMessage "Configuration key '$_configKey' NOT found in any of configuration files" $ERROR_CONFIG_VARIOUS
      printf "configuration key '$_configKey' \E[31mNOT FOUND\E[0m in any of configuration files" && return $ERROR_CONFIG_VARIOUS
    fi
  fi

  # Gets the value (may be empty).
  # N.B.: in case there is several, takes only the last one (interesting when there is several definition in configuration file).
  grep -e "^$_configKey=" "$configFileToRead" 2>/dev/null|sed -e 's/^[^=]*=//;s/"//g;' |tail -n 1
  return 0
}

# usage: getConfigValue <supported values> <value to check>
function checkAvailableValue() {
  [ "$( echo "$1" |grep -cw "$2" )" -eq 1 ]
}

# usage: isAbsolutePath <path>
# "true" if the path begins with "/"
function isAbsolutePath() {
  [[ "$1" =~ "^\/.*$" ]]
}

# usage: isSimplePath <path>
# "true" if there is NO "/" character (and so the tool should be in PATH)
function isSimplePath() {
  [[ "$1" =~ "^[^\/]*$" ]]
}

# usage: buildCompletePath <path> [<path to prepend> <force prepend>]
# <path to prepend>: the path to prepend if the path is NOT absolute and NOT simple.
# Defaut <path to prepend> is $ROOT_DIR
# <force prepend>: 0=disabled (default), 1=force prepend for "single path" (useful for data file)
function buildCompletePath() {
  local _path="$( pruneSlash "$1" )" _pathToPreprend="${2:-${ROOT_DIR:-$DEFAULT_ROOT_DIR}}" _forcePrepend="${3:-0}"

  # Replaces potential '~' character.
  if [[ "$_path" =~ "^~.*$" ]]; then
    homeForSed=$( echo "$( pruneSlash "$HOME" )" |sed -e 's/\//\\\//g;' )
    _path=$( echo "$_path" |sed -e "s/^~/$homeForSed/" )
  fi

  # Checks if it is an absolute path.
  isAbsolutePath "$_path" && echo "$_path" && return 0

  # Checks if it is a "simple" path.
  isSimplePath "$_path" && [ "$_forcePrepend" -eq 0 ] && echo "$_path" && return 0

  # Prefixes with install directory path.
  echo "$_pathToPreprend/$_path"
}

# usage: checkPath <path>
function checkPath() {
  # Informs only if not in 'MODE_CHECK_CONFIG_AND_QUIT' mode.
  [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && info "Checking path '$1' ... "

  # Checks if the path exists.
  [ -e "$1" ] && return 0

  # It is not the case, if NOT in 'MODE_CHECK_CONFIG_AND_QUIT' mode, it is a fatal error.
  [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && errorMessage "Unable to find '$1'." $ERROR_CHECK_CONFIG
  # Otherwise, simple returns an error code.
  return $ERROR_CHECK_CONFIG
}

# usage: checkBin <binary name/path>
function checkBin() {
  # Informs only if not in 'MODE_CHECK_CONFIG_AND_QUIT' mode.
  [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && info "Checking binary '$1' ... "

  # Checks if the binary is available.
  which "$1" >/dev/null 2>&1 && return 0

  # It is not the case, if NOT in 'MODE_CHECK_CONFIG_AND_QUIT' mode, it is a fatal error.
  [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && errorMessage "Unable to find binary '$1'." $ERROR_CHECK_BIN
  # Otherwise, simple returns an error code.
  return $ERROR_CHECK_BIN
}

# usage: checkDataFile <data file path>
function checkDataFile() {
  # Informs only if not in 'MODE_CHECK_CONFIG_AND_QUIT' mode.
  [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && info "Checking data file '$1' ... "

  # Checks if the file exists.
  [ -f "$1" ] && return 0

  # It is not the case, if NOT in 'MODE_CHECK_CONFIG_AND_QUIT' mode, it is a fatal error.
  [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && errorMessage "Unable to find data file '$1'." $ERROR_CHECK_CONFIG
  # Otherwise, simple returns an error code.
  return $ERROR_CHECK_CONFIG
}

# usage: checkAndGetConfig <config key> <config type> [<path to prepend>] [<toggle: must exist>]
# <config key>: the full config key corresponding to configuration element in configuration file
# <config type>: the type of config among
#   $CONFIG_TYPE_PATH: path -> path existence will be checked
#   $CONFIG_TYPE_OPTION: options -> nothing more will be done
#   $CONFIG_TYPE_BIN: binary -> system will ensure binary path is available
#   $CONFIG_TYPE_DATA: data -> data file path existence will be checked
# <path to prepend>: (only for type $CONFIG_TYPE_BIN and $CONFIG_TYPE_DATA) the path to prepend if
#  the path is NOT absolute and NOT simple. Defaut <path to prepend> is $ROOT_DIR
# <toggle: must exist>: only for CONFIG_TYPE_PATH; 1 (default) if path must exist, 0 otherwise.
# If all is OK, it defined the LAST_READ_CONFIG variable with the requested configuration element.
function checkAndSetConfig() {
  local _configKey="$1" _configType="$2" _pathToPreprend="${3:-${ROOT_DIR:-$DEFAULT_ROOT_DIR}}" _pathMustExist="${4:-1}"
  export LAST_READ_CONFIG="$CONFIG_NOT_FOUND" # reinit global variable.

  [ -z "$_configKey" ] && errorMessage "checkAndSetConfig function badly used (configuration key not specified)"
  [ -z "$_configType" ] && errorMessage "checkAndSetConfig function badly used (configuration type not specified)"

  local _message="Checking '$_configKey' ... "

  # Informs about config key to check, according to situation:
  #  - in 'normal' mode, message is only shown in VERBOSE mode
  #  - in 'MODE_CHECK_CONFIG_AND_QUIT' mode, message is always shown
  [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && info "$_message" || writeMessageSL "$_message"

  # Gets the value, according to the type of config.
  _value=$( getConfigValue "$_configKey" )
  valueGetStatus=$?
  if [ $valueGetStatus -ne 0 ]; then
    # Prints error message is any.
    [ -n "$_value" ] && echo -e "$_value" |tee -a "$LOG_FILE"
    # If NOT in 'MODE_CHECK_CONFIG_AND_QUIT' mode, it is a fatal error, so exists.
    [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && exit $valueGetStatus
    # Otherwise, simply returns an error status.
    return $valueGetStatus
  fi

  # Manages path if needed (it is the case for PATH, BIN and DATA).
  checkPathStatus=0
  if [ "$_configType" -ne $CONFIG_TYPE_OPTION ]; then
    [ "$_configType" -eq $CONFIG_TYPE_DATA ] && forcePrepend=1 || forcePrepend=0
    _value=$( buildCompletePath "$_value" "$_pathToPreprend" $forcePrepend )

    if [ "$_configType" -eq $CONFIG_TYPE_PATH ] && [ "$_pathMustExist" -eq 1 ]; then
      checkPath "$_value"
      checkPathStatus=$?
    elif [ "$_configType" -eq $CONFIG_TYPE_BIN ]; then
      checkBin "$_value"
      checkPathStatus=$?
    elif [ "$_configType" -eq $CONFIG_TYPE_DATA ]; then
      checkDataFile "$_value"
      checkPathStatus=$?
    fi
  fi

  # Ensures path check has been successfully done.
  if [ $checkPathStatus -ne 0 ]; then
    # If NOT in 'MODE_CHECK_CONFIG_AND_QUIT' mode, it is a fatal error, so exits.
    [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && exit $checkPathStatus
    # Otherwise, show an error message, and simply returns an error status.
    echo -e "'$_value' \E[31mNOT FOUND\E[0m" |tee -a "$LOG_FILE"
    return $checkPathStatus
  fi

  # Here, all is OK, there is nothing more to do.
  [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 1 ] && echo "OK" |tee -a "$LOG_FILE"

  # Sets the global variable
  export LAST_READ_CONFIG="$_value"
  return 0
}

# usage: checkAndFormatPath <paths>
# ALL paths must be specified if a single parameter.
function checkAndFormatPath() {
  local _paths="$1"

  formattedPath=""
  for pathToCheckRaw in $( echo "$_paths" |sed -e 's/[ ]/€/g;s/:/ /g;' ); do
    pathToCheck=$( echo "$pathToCheckRaw" |sed -e 's/€/ /g;' )

    # Defines the completes path, according to absolute/relative path.
    completePath="$pathToCheck"
    ! isAbsolutePath "$pathToCheck" && completePath="${ROOT_DIR:-$DEFAULT_ROOT_DIR}/$pathToCheck"

    # Uses "ls" to complete the path in case there is wildcard.
    if [ "$( echo "$completePath" |grep -c "*" )" -eq 1 ]; then
      formattedWildcard=$( echo "$completePath" |sed -e 's/^/"/;s/$/"/;s/*/"*"/g;s/""$//;' )
      completePath="$( ls -d "$( eval echo "$formattedWildcard" )" 2>/dev/null )" || echo -e "\E[31mNOT FOUND\E[0m" |tee -a "$LOG_FILE"
    fi

    # Checks if it exists, if 'MODE_CHECK_CONFIG_AND_QUIT' mode.
    if [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 1 ]; then
      writeMessageSL "Checking path '$pathToCheck' ... "
      [ -d "$completePath" ] && echo "OK" |tee -a "$LOG_FILE" || echo -e "\E[31mNOT FOUND\E[0m" |tee -a "$LOG_FILE"
    fi

    # In any case, updates the formatted path list.
    formattedPath=$formattedPath:$completePath
  done
  echo "$formattedPath"
}

#########################
## Functions - uptime

# usage: initializeUptime
function initializeStartTime() {
  date +'%s' > "${TIME_FILE:-$DEFAULT_TIME_FILE}"
}

# usage: finalizeStartTime
function finalizeStartTime() {
  rm -f "${TIME_FILE:-$DEFAULT_TIME_FILE}"
}

# usage: getUptime
function getUptime() {
  [ ! -f "${TIME_FILE:-$DEFAULT_TIME_FILE}" ] && echo "not started" && exit 0

  local _currentTime=$( date +'%s' )
  local _startTime=$( cat "${TIME_FILE:-$DEFAULT_TIME_FILE}" )
  local _uptime=$((_currentTime - _startTime))

  printf "%02dd %02dh:%02dm.%02ds" $((_uptime/86400)) $((_uptime%86400/3600)) $((_uptime%3600/60)) $((_uptime%60))
}

#########################
## Functions - source code management
# usage: manageJavaHome
# Ensures JAVA environment is ok, and ensures JAVA_HOME is defined.
function manageJavaHome() {
  # Checks if environment variable JAVA_HOME is defined.
  if [ -z "$JAVA_HOME" ]; then
    # Checks if it is defined in configuration file.
    checkAndSetConfig "environment.java.home" "$CONFIG_TYPE_OPTION"
    declare -r javaHome="$LAST_READ_CONFIG"
    if [ -z "$javaHome" ] || [[ "$javaHome" == "$CONFIG_NOT_FOUND" ]]; then
      # It is a fatal error but in 'MODE_CHECK_CONFIG_AND_QUIT' mode.
      local _errorMessage="You must either configure JAVA_HOME environment variable or environment.java.home configuration element."
      [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && errorMessage "$_errorMessage" $ERROR_ENVIRONMENT
      warning "$_errorMessage" && return 0
    fi

    # Ensures it exists.
    if [ ! -d "$javaHome" ]; then
      # It is a fatal error but in 'MODE_CHECK_CONFIG_AND_QUIT' mode.
      local _errorMessage="environment.java.home defined '$javaHome' which is not found."
      [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && errorMessage "$_errorMessage" $ERROR_CONFIG_VARIOUS
      warning "$_errorMessage" && return 0
    fi

    export JAVA_HOME="$javaHome"
  fi

  # Ensures it is a jdk home directory.
  local _javaPath="$JAVA_HOME/bin/java"
  local _javacPath="$JAVA_HOME/bin/javac"
  _errorMessage=""
  if [ ! -f "$_javaPath" ]; then
    _errorMessage="Unable to find java binary, ensure '$JAVA_HOME' is the home of a Java Development Kit version 6."
  elif [ ! -f "$_javacPath" ]; then
    _errorMessage="Unable to find javac binary, ensure '$JAVA_HOME' is the home of a Java Development Kit version 6."
  fi

  if [ -n "$_errorMessage" ]; then
    # It is a fatal error but in 'MODE_CHECK_CONFIG_AND_QUIT' mode.
    [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && errorMessage "$_errorMessage" $ERROR_ENVIRONMENT
    warning "$_errorMessage" && return 0
  fi

  writeMessage "Found: $( "$_javaPath" -version 2>&1|head -n 2| sed -e 's/$/ [/;' |tr -d '\n' |sed -e 's/..$/]/' )"
}

# usage: manageAntHome
# Ensures ANT environment is ok, and ensures ANT_HOME is defined.
function manageAntHome() {
  # Checks if environment variable ANT_HOME is defined.
  if [ -z "$ANT_HOME" ]; then
    # Checks if it is defined in configuration file.
    checkAndSetConfig "environment.ant.home" "$CONFIG_TYPE_OPTION"
    declare -r antHome="$LAST_READ_CONFIG"
    if [ -z "$antHome" ] || [[ "$antHome" == "$CONFIG_NOT_FOUND" ]]; then
      # It is a fatal error but in 'MODE_CHECK_CONFIG_AND_QUIT' mode.
      local _errorMessage="You must either configure ANT_HOME environment variable or environment.ant.home configuration element."
      [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && errorMessage "$_errorMessage" $ERROR_ENVIRONMENT
      warning "$_errorMessage" && return 0
    fi

    # Ensures it exists.
    if [ ! -d "$antHome" ]; then
      # It is a fatal error but in 'MODE_CHECK_CONFIG_AND_QUIT' mode.
      local _errorMessage="environment.ant.home defined '$antHome' which is not found."
      [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && errorMessage "$_errorMessage" $ERROR_CONFIG_VARIOUS
      warning "$_errorMessage" && return 0
    fi

    export ANT_HOME="$antHome"
  fi

  # Checks ant is available.
  local _antPath="$ANT_HOME/bin/ant"
  if [ ! -f "$_antPath" ]; then
    # It is a fatal error but in 'MODE_CHECK_CONFIG_AND_QUIT' mode.
    local _errorMessage="Unable to find ant binary, ensure '$ANT_HOME' is the home of an installation of Apache Ant."
    [ "$MODE_CHECK_CONFIG_AND_QUIT" -eq 0 ] && errorMessage "$_errorMessage" $ERROR_ENVIRONMENT
    warning "$_errorMessage" && return 0
  fi

  writeMessage "Found: $( "$_antPath" -v 2>&1|head -n 1 )"
}
