#!/bin/bash
############################################################################
# Pegasus' Linux Administration Tools #		 PostInstall Functions Library #
# (C)2017-2018 Mattijs Snepvangers	  #				 pegasus.ict@gmail.com #
# License: MIT						  # Please keep my name in the credits #
############################################################################

#########################################################
# PROGRAM_SUITE="Pegasus' Linux Administration Tools"	#
# SCRIPT_TITLE="Contaienr Tool Set Functions Library"	#
# MAINTAINER="Mattijs Snepvangers"						#
# MAINTAINER_EMAIL="pegasus.ict@gmail.com"				#
# VERSION_MAJOR=0										#
# VERSION_MINOR=1										#
# VERSION_PATCH=41										#
# VERSION_STATE="PRE-ALPHA"								#
# VERSION_BUILD=20180525								#
# LICENSE="MIT"											#
#########################################################

build_maintenance_script() { ###TODO### convert to template
	local _SCRIPT=$1
	local _SCRIPT_INI="${_SCRIPT%.*}.ini"
	local _SCRIPT_TITLE="$CONTAINER_SCRIPT_TITLE"
	# check for existing maintenance script
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

	sed -e 1d maintenance/body-basic.sh >> "$_SCRIPT"
}

check_cont_role() {
	local _CONTAINER=$1
	case "$_CONTAINER" in
		"nas"		)	SYSTEM_ROLE[NAS]=true		;	SYSTEM_ROLE[SERVER]=true								;	dbg_line "container=nas"		;;
		"web"		)	SYSTEM_ROLE[NAS]=true		;	SYSTEM_ROLE[SERVER]=true	;	SYSTEM_ROLE[WEB]=true	;	dbg_line "container=web"		;;
		"x11"		)	SYSTEM_ROLE[WS]=true		;	SYSTEM_ROLE[SERVER]=true								;	dbg_line "container=x11"		;;
		"pxe"		)	SYSTEM_ROLE[NAS]=true		;	SYSTEM_ROLE[SERVER]=true	;	SYSTEM_ROLE[PXE]=true	;	dbg_line "container=pxe"		;;
		"basic"		)	SYSTEM_ROLE[BASIC]=true																	;	dbg_line "container=basic"		;;
		"router"	)	SYSTEM_ROLE[ROUTER]=true	;	SYSTEM_ROLE[SERVER]=true								;	dbg_line "container=router"		;;
		"honeypot"	)	SYSTEM_ROLE[HONEY]=true		;	SYSTEM_ROLE[SERVER]=true								;	dbg_line "container=honeypot"	;;
		"firewall"	)	SYSTEM_ROLE[FIREWALL]=true	;	SYSTEM_ROLE[SERVER]=true								;	dbg_line "container=firewall"	;;
		*			)	crit_line "CRITICAL: Unknown containertype $_CONTAINER, exiting..."	;	exit 1	;;
	esac;
}
