#!/bin/bash
############################################################################
# Pegasus' Linux Administration Tools #				container build script #
# (C)2017-2018 Mattijs Snepvangers	  #				 pegasus.ict@gmail.com #
# License: MIT						  # Please keep my name in the credits #
############################################################################
START_TIME=$(date +"%Y-%m-%d_%H.%M.%S.%3N")
# Making sure this script is run by bash to prevent mishaps
if [ "$(ps -p "$$" -o comm=)" != "bash" ]; then bash "$0" "$@" ; exit "$?" ; fi
# Make sure only root can run this script
if [[ $EUID -ne 0 ]]; then echo "This script must be run as root" ; exit 1 ; fi
echo "$START_TIME ## Starting PostInstall Process #######################"
### FUNCTIONS ###
init() {
	################### PROGRAM INFO ##############################################
	declare -gr PROGRAM_SUITE="Pegasus' Linux Administration Tools"
	declare -gr SCRIPT="${0##*/}"
	declare -gr SCRIPT_DIR="${0%/*}"
	declare -gr SCRIPT_TITLE="Container Build Script"
	declare -gr MAINTAINER="Mattijs Snepvangers"
	declare -gr MAINTAINER_EMAIL="pegasus.ict@gmail.com"
	declare -gr COPYRIGHT="(c)2017-$(date +"%Y")"
	declare -gr VERSION_MAJOR=0
	declare -gr VERSION_MINOR=0
	declare -gr VERSION_PATCH=0
	declare -gr VERSION_STATE="PRE-ALPHA"
	declare -gr VERSION_BUILD=20180525
	declare -gr LICENSE="MIT"
	###############################################################################
	declare -gr PROGRAM="$PROGRAM_SUITE - $SCRIPT_TITLE"
	declare -gr SHORT_VERSION="$VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH-$VERSION_STATE"
	declare -gr VERSION="Ver$SHORT_VERSION build $VERSION_BUILD"
}

prep() {
	### VARS ###
	declare -g CONTAINER_NAME=""
	declare -Ag SYSTEM_ROLE(
		[BASIC]=false
		[WS]=false
		[SERVER]=false
		[NAS]=false
		[WEB]=false
		[PXE]=false
		[X11]=false
		[HONEY]=false
	)
	
	### INCLUDES ###
	source ../PBFL/default.inc.bash
	
	### LOAD PREFS ###
	parse_ini
	parse_args $@
	compile_prefs
	update _ini
}

main() {
	CONTAINER_NAME=$(prompt "What should the container be named?")
	#if [ $(choose "Do you want a specific version?") ]
	echo possible roles:
	for ROLE in SYSTEM_ROLE
	do
		echo -e "$SYSTEM_ROLE[ROLE]\n"
	done 
	CHOSEN_ROLES=$(prompt "what roles should the container perform?")

	create_container $CONTAINER_NAME true
	put_in_container "/etc/plat/*" "$CONTAINER_PATH$CONTAINER_NAME/etc/plat/"
	lxc exec $CONTAINER_NAME "bash /etc/plat/postinstall.sh -v 0 -r $CHOSEN_ROLES"
}

### boilerplate ###
init
prep $@
main
