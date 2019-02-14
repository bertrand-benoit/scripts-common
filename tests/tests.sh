#!/bin/bash
##
## Author: Bertrand Benoit <mailto:contact@bertrand-benoit.net>
## Description: Tests all features provided by utilities script.
## Version: 0.1

VERBOSE=1
CATEGORY="scriptTester"

currentDir=$( dirname "$( which "$0" )" )
source "$currentDir/../utilities.sh"

# Messages tests.
writeMessage "Simple message tests (should not have prefix)"
info "Info message test"
warning "Warning message test"
errorMessage "Error message test" -1 # -1 to avoid automatic exit of the script

# Conditional tests ...
# Script should NOT break because of the pipe status ...
[ 0 -gt 1 ] || echo "fake test ..."

# Time tests.
info "Testing time feature"
initializeStartTime
sleep 5
writeMessage "Uptime: $( getUptime )"
