#!/bin/bash
############################################################################
# Pegasus' Linux Administration Tools #					Container Tool Set #
# (C)2017-2018 Mattijs Snepvangers	  #				 pegasus.ict@gmail.com #
# License: MIT						  # Please keep my name in the credits #
############################################################################
START_TIME=$(date +"%Y-%m-%d_%H.%M.%S.%3N")
# Making sure this script is run by bash to prevent mishaps
if [ "$(ps -p "$$" -o comm=)" != "bash" ]; then bash "$0" "$@" ; exit "$?" ; fi
# Make sure only root can run this script
if [[ $EUID -ne 0 ]]; then echo "This script must be run as root" ; exit 1 ; fi
echo "$START_TIME ## Starting Container Tool Set Process #######################"

### FUNCTIONS ###
init() {
	################### PROGRAM INFO ##########################################
	declare -gr PROGRAM_SUITE="Pegasus' Linux Administration Tools"
	declare -gr SCRIPT="${0##*/}" ###CHECK###
	declare -gr SCRIPT_TITLE="Container Tool Set"
	declare -gr MAINTAINER="Mattijs Snepvangers"
	declare -gr MAINTAINER_EMAIL="pegasus.ict@gmail.com"
	declare -gr COPYRIGHT="(c)2017-$(date +"%Y")"
	declare -gr VERSION_MAJOR=0
	declare -gr VERSION_MINOR=0
	declare -gr VERSION_PATCH=27
	declare -gr VERSION_STATE="PRE-ALPHA"
	declare -gr VERSION_BUILD=20180419
	declare -gr LICENSE="MIT"
	###########################################################################
	declare -gr PROGRAM="$PROGRAM_SUITE - $SCRIPT_TITLE"
	declare -gr SHORT_VERSION="$VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH-$VERSION_STATE"
	declare -gr VERSION="Ver$SHORT_VERSION build $VERSION_BUILD"

}
prep() {
	declare -Ag SYSTEM_ROLE(
		[BASIC]=false
		[WS]=false
		[SERVER]=false
		[NAS]=false
		[WEB]=false
		[PXE]=false
		[X11]=false
	)

}
###############################################################################
_now=$(date +"%Y-%m-%d_%H.%M.%S.%3N")
mkdir '/var/log/plat'
touch $PLAT_LOG_FILE
echo "################################################################################" 2>&1 | tee -a $PLAT_LOG_FILE
echo "## Pegasus' Linux Administration Tools - Container Builder		   V1.0Beta ##" 2>&1 | tee -a $PLAT_LOG_FILE
echo "## (c) 2017 Mattijs Snepvangers	build 20180226	   pegasus.ict@gmail.com ##" 2>&1 | tee -a $PLAT_LOG_FILE
echo "################################################################################" 2>&1 | tee -a $PLAT_LOG_FILE
echo "" 2>&1 | tee -a $PLAT_LOG_FILE
source ../PBFL/default.inc.bash


################################################################################
getargs $@

print $systemrole


### send email with log attached
/etc/plat/mail.sh
