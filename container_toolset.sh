#!/bin/bash
############################################################################
# Pegasus' Linux Administration Tools #					postinstall script #
# (C)2017-2018 Mattijs Snepvangers	  #				 pegasus.ict@gmail.com #
# License: GPL v3					  # Please keep my name in the credits #
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
	declare -gr VERSION_PATCH=25
	declare -gr VERSION_STATE="PRE-ALPHA"
	declare -gr VERSION_BUILD=20180418
	declare -gr LICENSE="MIT"
	###########################################################################
	declare -gr PROGRAM="$PROGRAM_SUITE - $SCRIPT_TITLE"
	declare -gr SHORT_VERSION="$VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH-$VERSION_STATE"
	declare -gr VERSION="Ver$SHORT_VERSION build $VERSION_BUILD"
	### set default values ####################################################
	VERBOSITY=3	;	TMP_AGE=2	;	GARBAGE_AGE=7	;	LOG_AGE=30
	LOG_DIR="/var/log/plat"		;	LOG_FILE="$LOGDIR/ContainerToolSet_$START_TIME.log"
}
###############################################################################
_now=$(date +"%Y-%m-%d_%H.%M.%S.%3N")
mkdir '/var/log/plat'
touch $PLAT_LOGFILE
echo "################################################################################" 2>&1 | tee -a $PLAT_LOGFILE
echo "## Pegasus' Linux Administration Tools - Container Builder           V1.0Beta ##" 2>&1 | tee -a $PLAT_LOGFILE
echo "## (c) 2017 Mattijs Snepvangers    build 20180226       pegasus.ict@gmail.com ##" 2>&1 | tee -a $PLAT_LOGFILE
echo "################################################################################" 2>&1 | tee -a $PLAT_LOGFILE
echo "" 2>&1 | tee -a $PLAT_LOGFILE
source lib/default.inc.bash
getargs() {
   TEMP=`getopt -o hn:c: --long help,name:,containertype: -n "$FUNCNAME" -- "$@"`
   if [ $? != 0 ] ; then return 1 ; fi
   eval set -- "$TEMP";
   local format='%s\n' escape='-E' line='-n' script clear='tput sgr0';
   while [[ ${1:0:1} == - ]]; do
      [[ $1 =~ ^-h|--help ]] && {
         cat <<-EOF
         USAGE:

         OPTIONS

           -n or --name tells the script what name the container needs to have.
              Valid options: max 63 chars: -, a-z, A-Z, 0-9
                             name may not start or end with a dash "-"
                             name may not start with a digit "0-9"
           -c or --containertype tells the script what kind of container we are working on.
              Valid options are: basic, nas, web, x11, pxe
EOF
         return;
      };
      [[ $1 == -- ]] && { shift; break; };
      [[ $1 =~ ^-n|--name$ ]] && { name="${2}"; shift 2; continue; };
      [[ $1 =~ ^-c|--containertype$ ]] && { containertype="${2}"; shift 2; continue; };
      break;
   done
   tput -S <<<"$script";
   $clear;
}

################################################################################
getargs $@

checkname() {
   filteredname=$(echo "$contname" | grep -Po "^[a-zA-Z][-a-zA-Z0-9]{0,61}[a-zA-Z0-9]$")
   if [$filteredname != $contname]
   then
      cat << EOF
I'm sorry, the name you proposed is invalid, please enter a valid name:
    > max 63 chars: -, a-z, A-Z, 0-9
    > name may not start or end with a dash "-"
    > name may not start with a digit "0-9""
EOF
      exit 1
   fi
}
#   read name
case "$containertype" in
   "nas" )      systemrole[nas]=true    ;;
   "web" )      systemrole[nas]=true
                systemrole[web]=true    ;;
   "x11" )      systemrole[ws]=true     ;;
   "pxe" )      systemrole[nas]=true
                systemrole[pxe]=true    ;;
       * )      systemrole[basic]=true  ;;
esac

print $systemrole

create_container() {
	CONTAINER_NAME="$1"
	CONTAINER_DISTRIBUTION="$2"
	CONTAINER_VERSION="$3"
	lxc launch "$CONTAINER_DISTRIBUTION":"$CONTAINER_VERSION" "$CONTAINER_NAME"
}
start_container() {
	_CONTAINER_NAME=$1
	lxc start $_CONTAINER_NAME
}
stop_container() {
	_CONTAINER_NAME=$1
	lxc stop $_CONTAINER_NAME
}
list_containers() {
	lxc list
}
run_post_install() {
	
}
run_in_container() {
	_COMMAND=$1
	_CONTAINER_NAME=$2
	lxc exec $_CONTAINER_NAME -- $_COMMAND | dbg_line
}
### send email with log attached
/etc/plat/mail.sh
