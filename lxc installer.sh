#!/bin/bash
################################################################################
# Pegasus' Linux Administration Tools	#					  LXC Installer #
# (C)2017-2018 Mattijs Snepvangers	#				 pegasus.ict@gmail.com #
# License: MIT							# Please keep my name in the credits #
################################################################################
# tpl version: 0.1.0-ALPHA
# tpl build: 20180622
START_TIME=$(date +"%Y-%m-%d_%H.%M.%S.%3N")

# !!! first replace (ctrl-h)
# 2018 with the current year
# "20180825" with todays date
# LXC Installer with the title of the script and adjust the number of tabs if needed for proper alignment

source ../lib/subheader.sh

# mod: bootstrap
# txt: This script is meant to run as bootstrap on a freshly installed system
#      to add tweaks, software sources, install extra packages and external
#      software which isn't available via PPA and generates a suitable
#      maintenance script which will be set in cron or anacron

# fun: init
# txt: declares global constants with program/suite information
# env: $0 is used to determine basepath and scriptname
# use: init
# api: prerun
init() {
	################### PROGRAM INFO ##########################################
	declare -gr PROGRAM_SUITE="Pegasus' Linux Administration Tools"
	declare -gr SCRIPT="${0##*/}"
	declare -gr SCRIPT_DIR="${0%/*}"
	declare -gr SCRIPT_TITLE="LXC Installer"
	declare -gr MAINTAINER="Mattijs Snepvangers"
	declare -gr MAINTAINER_EMAIL="pegasus.ict@gmail.com"
	declare -gr COPYRIGHT="(c)2017-$(date +"%Y")"
	declare -gr VER_MAJOR=0
	declare -gr VER_MINOR=0
	declare -gr VER_PATCH=0
	declare -gr VER_STATE="PRE-ALPHA"
	declare -gr BUILD="20180825"
	declare -gr LICENSE="MIT"
	############################################################################
	declare -gr PROGRAM="$PROGRAM_SUITE - $SCRIPT_TITLE"
	declare -gr SHORT_VER="$VER_MAJOR.$VER_MINOR.$VER_PATCH-$VER_STATE"
	declare -gr VER="Ver$SHORT_VER build $BUILD"
}

# fun: config
# txt: config set as the name suggests, the configuration
# use: config
# api: prerun
config() {
	declare -Ag LXC_CFG
	declare -Ag LXC_IMG_SRV=(
		['IMG_CACHE_DAYS']=30
		['IMG_UPDATE_HRS']=24
	)
	declare -Ag LXD_CFG=(
		['HTTPS_ADDR']="[::]"
		['TRUST_PASS']="some-secret-string"
	)

}

# fun: prep
# txt: prep initializes default settings, imports the PBFL index and makes
#      other preparations needed by the script
# use: prep
# api: prerun
prep() {
	import "../PBFL/default.inc.bash"
	create_dir "$LOG_DIR"
	import "$LIB"
	header
	#parse_ini
	#get_args
}

# fun: lxc_install
# txt: Installs LXC, LXD, Juju and some extras
# use: lxc_install
# api: LXC Installer
lxc_install() {
	add_ppa_key "aar" "ppa:juju/stable"
	apt_update
	apt_inst_with_recs lxc lxd lxd-tools juju juju-deployer criu ctop lxctl lxctemplates nova-compute-lxd
}

# fun: lxc_setup
# txt: Installs LXC, LXD, Juju and some extras
# use: lxc_setup
# api: LXC Installer
lxc_setup() {
	lxd init
	lxc config set core.https_address "${LXD_CFG['HTTPS_ADDR']}"
	lxc config set core.trust_password "${LXD_CFG['TRUST_PASS']}"
	lxc config set images.remote_cache_expiry "${LXC_IMG_SRV['IMG_CACHE_DAYS']}"
	lxc config set images.auto_update_interval "${LXC_IMG_SRV['IMG_UPDATE_HRS']}"
	lxc config set images.auto_update_cached true
}

##### BOILERPLATE #####
init
prep
main
