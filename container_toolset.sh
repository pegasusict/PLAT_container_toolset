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


###
	get_args $@
}

get_args() {
	getopt --test > /dev/null
	if [[ $? -ne 4 ]]
	then
		err_line "I’m sorry, \"getopt --test\" failed in this environment."
		exit 1
	fi
	OPTIONS="hn:c:v:"
	LONG_OPTIONS="help,name:,containertype:,verbosity:"
	PARSED=$(getopt -o $OPTIONS --long $LONG_OPTIONS -n "$0" -- "$@")
	if [ $? -ne 0 ]
		then usage
	fi
	eval set -- "$PARSED"
	while true; do
		case "$1" in
			-h|--help			)	usage				;	shift	;;
			-v|--verbosity		)	set_verbosity $2	;	shift 2	;;
			-n|--name			)	check_name $2		;	shift 2	;;
			-c|--containertype	)	check_container $2	;	shift 2	;;
			--					)	shift				;	break	;;
			*					)	break							;;
		esac
	done
}

usage() {
	version
	cat <<-EOT
		USAGE:

		OPTIONS

		    -n or --name tells the script what name the container needs to have.
		       Valid options: max 63 chars: -, a-z, A-Z, 0-9
		                      name may not start or end with a dash "-"
		                      name may not start with a digit "0-9"
		    -c or --containertype tells the script what kind of container we are working on.
		       Valid options are: basic, nas, web, x11, pxe, basic, router, honeypot
		EOT
	exit 3
}

main() {
	
}


#### BOILERPLATE ####
init
prep $@
main
