#!/bin/bash
#
# Author: Bertrand BENOIT <bertrand.benoit@bsquare.no-ip.org>
# Version: 1.0
# Description: provides lots of utilities functions.

#########################
## Global variables
verbose=0

#########################
## Functions

# usage: writeMessage <message> [<0 or 1>]
# 0: keep on the same line
# 1: move to next line
function writeMessage() {
  local message="$1"
  messageTime=$(date +"%d/%m/%y %H:%M.%S")

  echoOption="-e"
  [ ! -z "$2" ] && [ "$2" -eq 0 ] && echoOption="-ne"

  echo $echoOption "$messageTime $message"
}

function info() {
  [ $verbose -eq 0 ] && return 0
  writeMessage "$1"
}

# usage: checkBin <binary name/path> [<binary name/path2> ... <binary name/path>N]
function checkBin() {
  info "Checking binary: $1"
  which "$1" >/dev/null 2>&1 && return 0
  writeMessage "Unable to find binary $1."
  return 1
}

