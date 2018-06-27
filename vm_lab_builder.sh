#!/bin/bash
############################################################################
# Pegasus' Linux Administration Tools #				container build script #
# (C)2017-2018 Mattijs Snepvangers	  #				 pegasus.ict@gmail.com #
# License: MIT						  # Please keep my name in the credits #
############################################################################
START_TIME=$(date +"%Y-%m-%d_%H.%M.%S.%3N")
source ../lib/subheader.sh
echo "$START_TIME ## Starting PostInstall Process #######################"
### FUNCTIONS ###
init() {
	################### PROGRAM INFO ##############################################
	declare -gr SCRIPT_TITLE="Container Build Script"
	declare -gr VERSION_MAJOR=0
	declare -gr VERSION_MINOR=1
	declare -gr VERSION_PATCH=0
	declare -gr VERSION_STATE="PRE-ALPHA"
	declare -gr VERSION_BUILD=20180626
	###############################################################################
	declare -gr PROGRAM="$PROGRAM_SUITE - $SCRIPT_TITLE"
	declare -gr SHORT_VERSION="$VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH-$VERSION_STATE"
	declare -gr VERSION="Ver$SHORT_VERSION build $VERSION_BUILD"
}

prep() {
	### VARS ###
	declare -g CONTAINER_NAME	;	CONTAINER_NAME=""
	declare -Ag SYSTEM_ROLE=(
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
	parse_args
	#compile_prefs
	#update _ini
}

# fun: build_farm
# txt: Setup an LXC vm farm quickly by creating VMs:
#      a) Attach bridge to vm
#      b) Assign an IPv4 address
#      c) Start VM
#      d) Mark VM as autostart on host reboot
# use:
# opt: VMs: space seperated list of names for the virtual machines
# api: lxc
build_farm() {
	_debug="" # either echo or ""
	_lxc="lxc"
	vm_arch='amd64'
	vm_bridge='br0'  # Your bridge interface
	vm_net_if='eth0'    # VM interface
	vm_start_ip='10.52.230' # Vm subnet 10.114.13.xx/24
	vm_first_ip=220           # First vm IP address 10.114.13.3 and so on
	## Customize this ##
	## Format:
	## vm_os/vm_version/vm_arch|vm-name
	vm_os=ubuntu
	vm_release=bionic
	declare -a vm_names=(theo, dominique, stefan, roelof)

	echo "Setting up LXD based VM lab...Please wait..."
	for v in $vm_names
	do
			# Get vm_os and vm_name
			IFS='|'
			set -- $v
			echo "* Creating ${2%%-*} vm...."
			# failsafe
		$_debug $_lxc info "$2" &>/dev/null && continue
			# Create vm
			$_debug $_lxc init "images:${1}" "$2"
			# Config networking for vm
			$_debug $_lxc network attach "$vm_bridge" "$2" "$vm_net_if"
			$_debug $_lxc config device set "$2" "$vm_net_if" ipv4.address "${vm_start_ip}.${vm_first_ip}"
			# Start vm
			$_debug $_lxc start "$2"
			$_debug $_lxc config set "$2" boot.autostart true
			# Increase an IP address counter
			(( vm_first_ip++ ))
	done
	echo "-------------------------------------------"
	echo '* VM Summary'
	echo "-------------------------------------------"
	$_lxc list


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
	OPTIONS="hn:c:v:"
	LONG_OPTIONS="help,name:,containertype:,verbosity:"
	PARSED=$(getopt -o $OPTIONS --long $LONG_OPTIONS -n "$" -- "$@")
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
		USAGE: sudo bash container_builder.sh -v [int]

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

### boilerplate ###
init
prep
main
