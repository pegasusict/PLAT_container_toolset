#!/bin/bash
################################################################################
# Pegasus' Linux Administration Tools	#					 Container Builder #
# (C)2017-2018 Mattijs Snepvangers		#				 pegasus.ict@gmail.com #
# License: MIT							#	Please keep my name in the credits #
################################################################################
START_TIME=$(date +"%Y-%m-%d_%H.%M.%S.%3N")
source ../lib/subheader.sh
echo loading...
###

init() {
	################### PROGRAM INFO ###########################################
	declare -gr SCRIPT_TITLE="Container Builder"
	declare -gr VER_MAJOR=0
	declare -gr VER_MINOR=1
	declare -gr VER_PATCH=10
	declare -gr VER_STATE="PRE-ALPHA"
	declare -gr BUILD=20180710
	############################################################################
	declare -gr PROGRAM="$PROGRAM_SUITE - $SCRIPT_TITLE"
	declare -gr SHORT_VER="$VER_MAJOR.$VER_MINOR.$VER_PATCH-$VER_STATE"
	declare -gr VER="Ver$SHORT_VER build $BUILD"
	############################################################################
	declare -gr OPTIONS="hn:c:v:"
	declare -gr LONG_OPTIONS="help,name:,containertype:,verbosity:"
	declare -gr	USAGE=<<-EOT
		USAGE: sudo bash container_builder.sh -v [int]

		OPTIONS

		    -n or --name tells the script what name the container needs to have.
		       Valid options: max 63 chars: -, a-z, A-Z, 0-9
		                      name may not start or end with a dash "-"
		                      name may not start with a digit "0-9"
		    -c or --containertype tells the script what kind of container we are working on.
		       Valid options are: basic, nas, web, pxe, x11, basic, honeypot, router or firewall
		EOT
}

prep() {
	### VARS ###
	declare -g CONTAINER_NAME	;	CONTAINER_NAME="container"
	declare -Ag SYSTEM_ROLE=(
							[BASIC]=false
							[WS]=false
							[SERVER]=false
							[NAS]=false
							[WEB]=false
							[PXE]=false
							[X11]=false
							[HONEY]=false
							[ROUTER]=false
							[FIREWALL]=false
							)
	### INCLUDES ###
	source ../PBFL/default.inc.bash
	### LOAD PREFS ###
	#parse_ini
	get_args
	parse_args
	#compile_prefs
	#update _ini
}

main() {
	echo "$START_TIME ## Starting $SCRIPT_TITLE Process #######################"
	CONTAINER_NAME=$(prompt "What should the container be named?")
	#if [ $(choose "Do you want a specific version?") ]
	echo possible roles:
	for ROLE in SYSTEM_ROLE
	do
		echo -e "$SYSTEM_ROLE[ROLE]\n"
	done
	CHOSEN_ROLES=$(prompt "what role(s) should the container perform?")

	create_container $CONTAINER_NAME true
	put_in_container "/etc/plat/*" "$CONTAINER_PATH$CONTAINER_NAME" "etc/plat/"
	lxc exec $CONTAINER_NAME "bash /etc/plat/postinstall.sh -v 0 -r $CHOSEN_ROLES"
}
get_args() {
	getopt --test > /dev/null
	if [[ $? -ne 4 ]]
	then
		err_line "I’m sorry, \"getopt --test\" failed in this environment."
		exit 1
	fi
	declare -gr PARSED=$(getopt -o $OPTIONS --long $LONG_OPTIONS -n "$" -- "$@")
	if [ $? -ne 0 ]
		then usage
	fi
}
parse_args() {
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
	cat $USAGE
	exit 3
}

### boilerplate ###
init
prep
main
