#!/bin/bash
############################################################################
# Pegasus' Linux Administration Tools #		 PostInstall Functions Library #
# (C)2017-2018 Mattijs Snepvangers	  #				 pegasus.ict@gmail.com #
# License: GPL v3					  # Please keep my name in the credits #
############################################################################

#########################################################
# PROGRAM_SUITE="Pegasus' Linux Administration Tools"	#
# SCRIPT_TITLE="Contaienr Tool Set Functions Library"	#
# MAINTAINER="Mattijs Snepvangers"						#
# MAINTAINER_EMAIL="pegasus.ict@gmail.com"				#
# VERSION_MAJOR=0										#
# VERSION_MINOR=1										#
# VERSION_PATCH=31										#
# VERSION_STATE="PRE-ALPHA"								#
# VERSION_BUILD=20180419								#
#########################################################

### Basic program #############################################################
get_args() { ### postinstall version as example
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
		       Valid options are: basic, nas, web, x11, pxe
		EOT
	exit 3
}

build_maintenance_script() { ###TODO### convert to template
	local _SCRIPT=$1
	local _SCRIPT_INI="${_SCRIPT%.*}.ini"
	if [[ "$_SCRIPT" == "$MAINTENANCE_SCRIPT" ]]
	then
		local _SCRIPT_TITLE="$MAINTENANCE_SCRIPT_TITLE"
	else
		local _SCRIPT_TITLE="$CONTAINER_SCRIPT_TITLE"
	fi
	if [ -f "$_SCRIPT" ]
	then
		rm "$_SCRIPT" 2>&1 | dbg_line
		info_line "Removed old maintenance script."
	fi
	add_to_script "$_SCRIPT" line "#!/usr/bin/bash"
	make_line >> "$_SCRIPT"
	header_line "$PROGRAM_SUITE - $_SCRIPT_TITLE" "Ver$SHORT_VERSION" >> "$_SCRIPT"
	header_line "$COPYRIGHT $MAINTAINER" "build $VERSION_BUILD  $MAINTAINER_EMAIL" >> "$_SCRIPT"
	header_line "This maintenance script is dynamically built" "Last build: $TODAY" >> "$_SCRIPT"
	header_line "License: $LICENSE" "Please keep my name in the credits" >> "$_SCRIPT"
	make_line >> "$_SCRIPT"
	sed -e 1d maintenance/maintenance-subheader1.sh >> "$_SCRIPT"
	add_to_script "$_SCRIPT" line "PROGRAM_SUITE=\"$PROGRAM_SUITE\""
	add_to_script "$_SCRIPT" line "SCRIPT_TITLE=\"$_SCRIPT_TITLE\""
	add_to_script "$_SCRIPT" line "VERSION_MAJOR=$VERSION_MAJOR"
	add_to_script "$_SCRIPT" line "VERSION_MINOR=$VERSION_MINOR"
	add_to_script "$_SCRIPT" line "VERSION_PATCH=$VERSION_PATCH"
	add_to_script "$_SCRIPT" line "VERSION_STATE=$VERSION_STATE"
	add_to_script "$_SCRIPT" line "VERSION_BUILD=$VERSION_BUILD"
	add_to_script "$_SCRIPT" line "MAINTAINER=\"$MAINTAINER\""
	add_to_script "$_SCRIPT" line "MAINTAINER_EMAIL=\"$MAINTAINER_EMAIL\""
	make_line >> "$_SCRIPT"
	make_line "#" 80 "### define CONSTANTS #"
	add_to_script "$_SCRIPT" line "declare -r LIB_DIR=\"$LIB_DIR\""
	add_to_script "$_SCRIPT" line "declare -r LIB=\"$LIB\""
	add_to_script "$_SCRIPT" line "declare -r INI_PRSR=\"$INI_PRSR\""
	make_line "#" 80 "### set default values #"
	add_to_script "$_SCRIPT" line "VERBOSITY=$VERBOSITY"
	add_to_script "$_SCRIPT" line "TMP_AGE=$TMP_AGE"
	add_to_script "$_SCRIPT" line "GARBAGE_AGE=$GARBAGE_AGE"
	add_to_script "$_SCRIPT" line "LOG_AGE=$LOG_AGE"
	add_to_script "$_SCRIPT" line "LOG_DIR=\"$LOG_DIR\""
	sed -e 1d maintenance/maintenance-subheader2.sh >> "$_SCRIPT"

	add_to_script "$_SCRIPT" line "verb_line <<EOH"
	make_line >> "$_SCRIPT"
	header_line "$PROGRAM_SUITE - $_SCRIPT_TITLE" "Ver$SHORT_VERSION" >> "$_SCRIPT"
	header_line "$COPYRIGHT $MAINTAINER" "build $VERSION_BUILD  $MAINTAINER_EMAIL" >> "$_SCRIPT"
	header_line "This maintenance script is dynamically built" "Last build: $TODAY" >> "$_SCRIPT"
	header_line "License: $LICENSE" "Please keep my name in the credits" >> "$_SCRIPT"
	make_line >> "$_SCRIPT"
	add_to_script "$_SCRIPT" line "EOH"

	info_line "generating ini file"
	add_to_script "$_SCRIPT_INI" line "GARBAGE_AGE=$GARBAGE_AGE"
	add_to_script "$_SCRIPT_INI" line "LOG_AGE=$LOG_AGE"
	add_to_script "$_SCRIPT_INI" line "TMP_AGE=$TMP_AGE"
	if [[ $SYSTEMROLE_CONTAINER == false ]]
	then
		if [[ $_SCRIPT == $MAINTENANCE_SCRIPT ]]
		then
			if [[ $SYSTEMROLE_LXCHOST == true ]]
			then
				sed -e 1d maintenance/body-lxchost0.sh >> "$_SCRIPT"
				if [[ $SYSTEMROLE_MAINSERVER == true ]]
				then
					sed -e 1d maintenance/backup2tape.sh >> "$_SCRIPT"
				fi
				sed -e 1d maintenance/body-lxchost1.sh >> "$_SCRIPT"
			fi
		fi
	fi
	sed -e 1d maintenance/body-basic.sh >> "$_SCRIPT"
}

check_container() {
	local _CONTAINER=$1
	case "$_CONTAINER" in
		"nas"		)	SYSTEMROLE_NAS=true		;	dbg_line "container=nas"	;;
		"web"		)	SYSTEMROLE_NAS=true		;
						SYSTEMROLE_WEB=true		;	dbg_line "container=web"	;;
		"x11"		)	SYSTEMROLE_WS=true		;	dbg_line "container=x11"	;;
		"pxe"		)	SYSTEMROLE_NAS=true		;
						SYSTEMROLE_PXE=true		;	dbg_line "container=pxe"	;;
		"basic"		)	SYSTEMROLE_BASIC=true	;	dbg_line "container=basic"	;;
		"router"	)	SYSTEMROLE_ROUTER=true	;	dbg_line "container=router"	;;
		*			)	crit_line "CRITICAL: Unknown containertype $CONTAINER, exiting..."	;	exit 1	;;
	esac;
}

check_name() {
	local _CONTAINER_NAME="$1"
	local _FILTERED_NAME=$(echo "$_CONTAINER_NAME" | grep -Po "^[a-zA-Z][-a-zA-Z0-9]{0,61}[a-zA-Z0-9]$")
	if [ $_FILTERED_NAME != $_CONTAINER_NAME ]
	then
		cat <<-EOT
			I'm sorry, the name you proposed is invalid, please enter a valid name:
			    > max 63 chars: -, a-z, A-Z, 0-9
			    > name may not start or end with a dash "-"
			    > name may not start with a digit "0-9""
			EOT
	  exit 1
	else declare -gr CONTAINER_NAME=$_CONTAINER_NAME
}
