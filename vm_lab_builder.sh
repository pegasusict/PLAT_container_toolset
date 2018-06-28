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
	################### PROGRAM INFO ###########################################
	declare -gr SCRIPT_TITLE="Container Build Script"
	declare -gr VERSION_MAJOR=0
	declare -gr VERSION_MINOR=1
	declare -gr VERSION_PATCH=2
	declare -gr VERSION_STATE="PRE-ALPHA"
	declare -gr VERSION_BUILD=20180628
	############################################################################
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
	local _LXC			;	_LXC="lxc"
	local _VM_ARCH		;	_VM_ARCH='amd64'
	local _VM_BRIDGE	;	_VM_BRIDGE='br0'
	local _VM_NET_IF	;	_VM_NET_IF='eth0'
	local _VM_START_IP	;	_VM_START_IP='192.168.49'
	local _VM_FIRST_IP	;	_VM_FIRST_IP=220
	local _NETCFG
	## Customize this ##
	## Format:
	## VM_OS/VM_VERSION/VM_ARCH|VM-NAME
	local _VM_OS		;	_VM_OS=ubuntu
	local _VM_VERSION	;	_VM_VERSION=bionic
	local -a _VM_NAMES=("$_VM_OS"/"$_VM_VERSION"/"$_VM_ARCH"|theo,
						"$_VM_OS"/"$_VM_VERSION"/"$_VM_ARCH"|dominique,
						"$_VM_OS"/"$_VM_VERSION"/"$_VM_ARCH"|stefan,
						"$_VM_OS"/"$_VM_VERSION"/"$_VM_ARCH"|roelof)

	echo "Setting up LXD based VM lab...Please wait..."
	for v in $vm_names
	do
		# Get VM_OS and VM_NAME
		IFS='|'
		set -- $v
		echo "* Creating ${2%%-*} vm...."
		# failsafe
		$_LXC info "$2" &>/dev/null && continue
		# Create vm
		$_LXC init "images:${1}" "$2"
		# Config networking for vm
		# Start vm
		$_LXC start "$2"
		_NETCFG="auto $_VM_NET_IF\n
		iface $_VM_NET_IF inet static\n
		address $_VM_START_IP.$_VM_FIRST_IP\n	netmask 255.255.255.0\n
		network $_VM_START_IP.0\n	broadcast $_VM_START_IP.255\n
		gateway $_VM_START_IP.254\n	dns-nameservers 8.8.8.8 8.8.4.4\n	"
		echo -e $_NETCFG
		$_LXC config set "$2" boot.autostart true
		# Increase an IP address counter
		(( VM_FIRST_IP++ ))
	done
	echo "-------------------------------------------"
	echo '* VM Summary'
	echo "-------------------------------------------"
	$_LXC list
}

		put_in_container "/etc/plat/*" "$CONTAINER_PATH$CONTAINER_NAME" "etc/plat/"
		lxc exec $CONTAINER_NAME "bash /etc/plat/postinstall.sh -v 0 -r $CHOSEN_ROLES"

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
