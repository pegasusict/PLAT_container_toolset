#!/bin/bash

# Detect use under userns (unsupported)
for arg in "$@"
do    [ "$arg" = "--" ] && break
	if [ "$arg" = "--mapped-uid" -o "$arg" = "--mapped-gid" ]
	then
		echo "This template can't be used for unprivileged containers." 1>&2
		echo "You may want to try the \"download\" template instead." 1>&2
		exit 1
	fi
done

# Make sure the usual locations are in PATH
export PATH=$PATH:/usr/sbin:/usr/bin:/sbin:/bin

set -e

LOCALSTATEDIR="@LOCALSTATEDIR@"
LXC_TEMPLATE_CONFIG="@LXCTEMPLATECONFIG@"
# Allows the lxc-cache directory to be set by environment variable
LXC_CACHE_PATH=${LXC_CACHE_PATH:-"$LOCALSTATEDIR/cache/lxc"}

if [ -r /etc/default/lxc ]
then
	source /etc/default/lxc
fi

# Check if given path is in a btrfs partition
is_btrfs() {
	[ -e $1 -a $(stat -f -c '%T' $1) = "btrfs" ]
}

# Check if given path is the root of a btrfs subvolume
is_btrfs_subvolume() {
	[ -d $1 -a $(stat -f -c '%T' $1) = "btrfs" -a $(stat -c '%i' $1) -eq 256 ]
}

try_mksubvolume() {
	local path	;	path=$1
	[ -d $path ] && return 0
	mkdir -p $(dirname $path)
	if which btrfs >/dev/null 2>&1 && is_btrfs $(dirname $path)
	then
		btrfs subvolume create $path
	else
		mkdir -p $path
	fi
}

try_rmsubvolume() {
	local path	;	path=$1
	[ -d $path ] || return 0
	if which btrfs >/dev/null 2>&1 && is_btrfs_subvolume $path
	then
		btrfs subvolume delete $path
	else
		rm -rf $path
	fi
}

configure_ubuntu() {
	local rootfs	;	rootfs=$1
	local hostname	;	hostname=$2
	local release	;	release=$3
	local user		;	user=$4
	local password	;	password=$5
	# configure the network using the dhcp
	if chroot $rootfs which netplan >/dev/null 2>&1
	then
		cat <<-EOF > $rootfs/etc/netplan/10-lxc.yaml
			network:
				ethernets:
					eth0: {dhcp4: true}
				version: 2
			EOF
	else
		cat <<-EOF > $rootfs/etc/network/interfaces
			# This file describes the network interfaces available on your system
			# and how to activate them. For more information, see interfaces(5).

			# The loopback network interface
			auto lo
			iface lo inet loopback

			auto eth0
			iface eth0 inet dhcp
			EOF
	fi

	# set the hostname
	cat <<-EOF > $rootfs/etc/hostname
		$hostname
		EOF
	# set minimal hosts
	cat <<-EOF > $rootfs/etc/hosts
		127.0.0.1   localhost
		127.0.1.1   $hostname

		# The following lines are desirable for IPv6 capable hosts
		::1     ip6-localhost ip6-loopback
		fe00::0 ip6-localnet
		ff00::0 ip6-mcastprefix
		ff02::1 ip6-allnodes
		ff02::2 ip6-allrouters
		EOF

	if [ ! -f $rootfs/etc/init/container-detect.conf ]
	then
		# suppress log level output for udev
		sed -i "s/=\"err\"/=0/" $rootfs/etc/udev/udev.conf

		# remove jobs for consoles 5 and 6 since we only create 4 consoles in
		#+ this template
		rm -f $rootfs/etc/init/tty{5,6}.conf
	fi

	if [ -z "$bindhome" ]
	then
		chroot $rootfs useradd --create-home -s /bin/bash $user
		echo "$user:$password" | chroot $rootfs chpasswd
	fi

	# make sure we have the current locale defined in the container
	if [ -z "$LANG" ] || echo $LANG | grep -E -q "^C(\..+)*$"
	then
		chroot $rootfs locale-gen en_US.UTF-8 || true
		chroot $rootfs update-locale LANG=en_US.UTF-8 || true
	else
		chroot $rootfs locale-gen $LANG || true
		chroot $rootfs update-locale LANG=$LANG || true
	fi

	# generate new SSH keys
	if [ -x $rootfs/var/lib/dpkg/info/openssh-server.postinst ]
	then
		cat > $rootfs/usr/sbin/policy-rc.d <<-EOF
			#!/bin/sh
			exit 101
			EOF
		chmod +x $rootfs/usr/sbin/policy-rc.d

		if [ -f "$rootfs/etc/init/ssh.conf" ]
		then
			mv "$rootfs/etc/init/ssh.conf" "$rootfs/etc/init/ssh.conf.disabled"
		fi

		rm -f $rootfs/etc/ssh/ssh_host_*key*

		DPKG_MAINTSCRIPT_PACKAGE=openssh DPKG_MAINTSCRIPT_NAME=postinst \
		chroot $rootfs /var/lib/dpkg/info/openssh-server.postinst configure

		sed -i "s/root@$(hostname)/root@$hostname/g" \
		$rootfs/etc/ssh/ssh_host_*.pub

		if [ -f "$rootfs/etc/init/ssh.conf.disabled" ]
		then
			mv "$rootfs/etc/init/ssh.conf.disabled" "$rootfs/etc/init/ssh.conf"
		fi

		rm -f $rootfs/usr/sbin/policy-rc.d
	fi

	return 0
}

# finish setting up the user in the container by injecting ssh key and
#+ adding sudo group membership.
# passed-in user is either 'ubuntu' or the user to bind in from host.
finalize_user() {
	local user	;	user=$1
	local sudo_version	;	sudo_version=$(chroot $rootfs dpkg-query -W -f='${Version}' sudo)
	if chroot $rootfs dpkg --compare-versions $sudo_version gt "1.8.3p1-1"
	then
		local groups	;	groups="sudo"
	else
		local groups	;	groups="sudo admin"
	fi
	for group in $groups
	do
		chroot $rootfs groupadd --system $group >/dev/null 2>&1 || true
		chroot $rootfs adduser ${user} $group >/dev/null 2>&1 || true
	done
	if [ -n "$auth_key" -a -f "$auth_key" ]
	then
		local u_path	;	u_path="/home/${user}/.ssh"
		local root_u_path	;	root_u_path="$rootfs/$u_path"
		mkdir -p $root_u_path
		cp $auth_key "$root_u_path/authorized_keys"
		chroot $rootfs chown -R ${user}: "$u_path"
		echo "Inserted SSH public key from $auth_key into /home/${user}/.ssh/authorized_keys"
	fi
	return 0
}

# A function to try and autodetect squid-deb-proxy servers on the local network
# if either the squid-deb-proxy-client package is installed on the host or
# a parent container set the 50squid-deb-proxy-client file.
squid_deb_proxy_autodetect() {
	local apt_discover ; apt_discover=/usr/share/squid-deb-proxy-client/apt-avahi-discover
	local proxy_file ; proxy_file=/etc/apt/apt.conf.d/50squid-deb-proxy-client
	declare -g squid_proxy_line

	# Maybe the host is aware of a squid-deb-proxy?
	if [ -f $apt_discover ]
	then
		echo -n "Discovering squid-deb-proxy..."
		squid_proxy_line=$($apt_discover)
		if [ -n "$squid_proxy_line" ]
		then
			echo "found squid-deb-proxy: $squid_proxy_line"
		else
			echo "no squid-deb-proxy found"
		fi
	fi

	# Are we in a nested container and the parent already knows of a proxy?
	if [ -f $proxy_file ]
	then
		# Extract the squid URL from the file (whatever is between "")
		squid_proxy_line=`cat $proxy_file | sed "s/.*\"\(.*\)\".*/\1/"`
	fi
}

# Choose proxies for container
# http_proxy will be used by debootstrap on the host.
# APT_PROXY will be used to set /etc/apt/apt.conf.d/70proxy in the container.
choose_container_proxy() {
	local rootfs	;	rootfs=$1
	local arch		;	arch=$2
	if [ -z "$HTTP_PROXY" ]
	then
		HTTP_PROXY="none"
	fi
	case "$HTTP_PROXY" in
		none)	squid_deb_proxy_autodetect
				if [ -n "$squid_proxy_line" ]
				then
					APT_PROXY=$squid_proxy_line
					export http_proxy=$squid_proxy_line
				else
					APT_PROXY=
				fi
				;;
		apt)
				RES=`apt-config shell APT_PROXY Acquire::http::Proxy`
				eval $RES
				[ -z "$APT_PROXY" ] || export http_proxy=$APT_PROXY
				;;
		*)
				APT_PROXY=$HTTP_PROXY
				export http_proxy=$HTTP_PROXY
				;;
	esac
}

write_sourceslist() {
	# $1 => path to the partial cache or the rootfs
	# $2 => architecture we want to add
	# $3 => whether to use the multi-arch syntax or not

	if [ -n "$APT_PROXY" ]
	then
		mkdir -p $1/etc/apt/apt.conf.d
		cat > $1/etc/apt/apt.conf.d/70proxy <<-EOF
			Acquire::http::Proxy "$APT_PROXY" ;
			EOF
	fi

	case $2 in
		amd64|i386)	MIRROR=${MIRROR:-http://archive.ubuntu.com/ubuntu}
					SECURITY_MIRROR=${SECURITY_MIRROR:-http://security.ubuntu.com/ubuntu}
					;;
		*)
					MIRROR=${MIRROR:-http://ports.ubuntu.com/ubuntu-ports}
					SECURITY_MIRROR=${SECURITY_MIRROR:-http://ports.ubuntu.com/ubuntu-ports}
					;;
	esac
	if [ -n "$3" ]
	then
		cat >> "$1/etc/apt/sources.list" <<-EOF
			deb [arch=$2] $MIRROR ${release} main restricted universe multiverse
			deb [arch=$2] $MIRROR ${release}-updates main restricted universe multiverse
			deb [arch=$2] $SECURITY_MIRROR ${release}-security main restricted universe multiverse
			EOF
	else
		cat >> "$1/etc/apt/sources.list" <<-EOF
			deb $MIRROR ${release} main restricted universe multiverse
			deb $MIRROR ${release}-updates main restricted universe multiverse
			deb $SECURITY_MIRROR ${release}-security main restricted universe multiverse
			EOF
	fi
}

install_packages() {
	local rootfs	;	rootfs="$1"
	shift
	local packages	;	packages="$*"
	if [ -z $update ]
	then
		chroot $rootfs apt-get update
		local update	;	update=true
	fi
	if [ -n "${packages}" ]
	then
		chroot $rootfs apt-get install --force-yes -y \
		--no-install-recommends ${packages}
	fi
}

cleanup() {
	try_rmsubvolume $cache/partial-$arch
	try_rmsubvolume $cache/rootfs-$arch
}

suggest_flush() {
	echo "Container upgrade failed. The container cache may be out of date,"
	echo "in which case flushing the cache (see -F in the help output) may help."
}

download_ubuntu() {
	local cache	;	cache=$1
	local arch	;	arch=$2
	local release	;	release=$3
	case $arch in
		amd64|i386)	MIRROR=${MIRROR:-http://archive.ubuntu.com/ubuntu}
					SECURITY_MIRROR=${SECURITY_MIRROR:-http://security.ubuntu.com/ubuntu}
					;;
		*)
					MIRROR=${MIRROR:-http://ports.ubuntu.com/ubuntu-ports}
					SECURITY_MIRROR=${SECURITY_MIRROR:-http://ports.ubuntu.com/ubuntu-ports}
					;;
	esac
	packages_template=${packages_template:-"apt-transport-https,ssh,vim"}
	debootstrap_parameters=
	# Try to guess a list of langpacks to install
	local langpacks	;	langpacks="language-pack-en"
	if which dpkg >/dev/null 2>&1
	then
		langpacks=`(echo $langpacks && \
					dpkg -l | grep -E "^ii  language-pack-[a-z]* " |
					cut -d ' ' -f3) | sort -u`
	fi
	packages_template="${packages_template},$(echo $langpacks | sed 's/ /,/g')"
	if [ -n "$variant" ]
	then
		debootstrap_parameters="$debootstrap_parameters --variant=$variant"
	fi
	if [ "$variant" = 'minbase' ]
	then
		packages_template="${packages_template},sudo"
		# Newer releases use netplan, EOL releases not supported
		case $release in
			trusty|xenial|zesty)	packages_template="${packages_template},ifupdown,isc-dhcp-client"
									;;
		esac
	fi
	echo "Installing packages in template: ${packages_template}"
	trap cleanup EXIT SIGHUP SIGINT SIGTERM
	# check the mini ubuntu was not already downloaded
	try_mksubvolume "$cache/partial-$arch"
	if [ $? -ne 0 ]
	then
		echo "Failed to create '$cache/partial-$arch' directory"
		return 1
	fi

	choose_container_proxy $cache/partial-$arch/ $arch
	# download a mini ubuntu into a cache
	echo "Downloading ubuntu $release minimal ..."
	if [ -n "$(which qemu-debootstrap)" ]
	then
		qemu-debootstrap --verbose $debootstrap_parameters \
		--components=main,universe --arch=$arch \
		--include=${packages_template} $release $cache/partial-$arch $MIRROR
	else
		debootstrap --verbose $debootstrap_parameters \
		--components=main,universe --arch=$arch --include=${packages_template} \
		$release $cache/partial-$arch $MIRROR
	fi

	if [ $? -ne 0 ]
	then
		echo "Failed to download the rootfs, aborting."
		return 1
	fi

	# Serge isn't sure whether we should avoid doing this when
	# $release == `distro-info -d`
	echo "Installing updates" > $cache/partial-$arch/etc/apt/sources.list
	write_sourceslist $cache/partial-$arch/ $arch

	chroot "$1/partial-${arch}" apt-get update
	if [ $? -ne 0 ]
	then
		echo "Failed to update the apt cache"
		return 1
	fi
	cat > "$1/partial-${arch}"/usr/sbin/policy-rc.d <<-EOF
		#!/bin/sh
		exit 101
		EOF
	chmod +x "$1/partial-${arch}"/usr/sbin/policy-rc.d

	(
		cat <<-EOF
			mount -t proc proc "${1}/partial-${arch}/proc"
			chroot "${1}/partial-${arch}" apt-get dist-upgrade -y
			EOF
	) | lxc-unshare -s MOUNT -- sh -eu || (suggest_flush; false)

	rm -f "$1/partial-${arch}"/usr/sbin/policy-rc.d

	chroot "$1/partial-${arch}" apt-get clean

	mv "$1/partial-$arch" "$1/rootfs-$arch"
	trap EXIT
	trap SIGINT
	trap SIGTERM
	trap SIGHUP
	echo "Download complete"
	return 0
}

copy_ubuntu() {
	local cache	;	cache=$1
	local arch	;	arch=$2
	local rootfs	;	rootfs=$3

	# make a local copy of the miniubuntu
	echo "Copying rootfs to $rootfs ..."
	try_mksubvolume $rootfs
	if which btrfs >/dev/null 2>&1 && is_btrfs_subvolume $cache/rootfs-$arch \
	&& is_btrfs_subvolume $rootfs
	then
		realrootfs=$(dirname $config)/rootfs
		[ "$rootfs" = "$realrootfs" ] || umount $rootfs || return 1
		btrfs subvolume delete $realrootfs || return 1
		btrfs subvolume snapshot $cache/rootfs-$arch $realrootfs || return 1
		[ "$rootfs" = "$realrootfs" ] || mount --bind $realrootfs $rootfs || return 1
	else
		rsync -SHaAX $cache/rootfs-$arch/ $rootfs/ || return 1
	fi
	return 0
}

install_ubuntu() {
	local rootfs	;	rootfs=$1
	local release	;	release=$2
	local flushcache	;	flushcache=$3
	local cache	;	cache="$4/$release"
	mkdir -p $LOCALSTATEDIR/lock/subsys/

	(
		flock -x 9
		if [ $? -ne 0 ]
		then
			echo "Cache repository is busy."
			return 1
		fi

		if [ $flushcache -eq 1 ]
		then
			echo "Flushing cache..."
			try_rmsubvolume $cache/partial-$arch
			try_rmsubvolume $cache/rootfs-$arch
		fi

		echo "Checking cache download in $cache/rootfs-$arch ... "
		if [ ! -e "$cache/rootfs-$arch" ]
		then
			download_ubuntu $cache $arch $release
			if [ $? -ne 0 ]
			then
				echo "Failed to download 'ubuntu $release base'"
				return 1
			fi
		fi

		echo "Copy $cache/rootfs-$arch to $rootfs ... "
		copy_ubuntu $cache $arch $rootfs
		if [ $? -ne 0 ]
		then
			echo "Failed to copy rootfs"
			return 1
		fi
		return 0
	) 9>$LOCALSTATEDIR/lock/subsys/lxc-ubuntu$release
	return $?
}

copy_configuration(){
	local path	;	path=$1
	local rootfs	;	rootfs=$2
	local name	;	name=$3
	local arch	;	arch=$4
	local release	;	release=$5

	if [ $arch = "i386" ]
	then
		arch="i686"
	fi

	# if there is exactly one veth network entry, make sure it has an
	# associated hwaddr.
	nics=`grep -e '^lxc\.net\.0\.type[ \t]*=[ \t]*veth' $path/config | wc -l`
	if [ $nics -eq 1 ]
	then
		grep -q "^lxc.net.0.hwaddr" $path/config || sed -i -e "/^lxc\.net\.0\.type[ \t]*=[ \t]*veth/a lxc.net.0.hwaddr = 00:16:3e:$(openssl rand -hex 3| sed 's/\(..\)/\1:/g; s/.$//')" $path/config
	fi

	# Generate the configuration file
	## Relocate all the network config entries
	sed -i -e "/lxc.net.0/{w ${path}/config-network" -e "d}" $path/config

	## Relocate any other config entries
	sed -i -e "/lxc./{w ${path}/config-auto" -e "d}" $path/config

	## Add all the includes
	echo "" >> $path/config
	echo "# Common configuration" >> $path/config
	if [ -e "${LXC_TEMPLATE_CONFIG}/ubuntu.common.conf" ]
	then
		echo "lxc.include = ${LXC_TEMPLATE_CONFIG}/ubuntu.common.conf" \
		>> $path/config
	fi
	if [ -e "${LXC_TEMPLATE_CONFIG}/ubuntu.${release}.conf" ]
	then
		echo "lxc.include = ${LXC_TEMPLATE_CONFIG}/ubuntu.${release}.conf" \
		>> $path/config
	fi

	## Add the container-specific config
	echo "" >> $path/config
	echo "# Container specific configuration" >> $path/config
	[ -e "$path/config-auto" ] && cat $path/config-auto >> $path/config && \
	rm $path/config-auto
	grep -q "^lxc.rootfs.path" $path/config 2>/dev/null || \
	echo "lxc.rootfs.path = $rootfs" >> $path/config
	cat <<-EOF >> $path/config
		lxc.uts.name = $name
		lxc.arch = $arch
		EOF

	## Re-add the previously removed network config
	echo "" >> $path/config
	echo "# Network configuration" >> $path/config
	cat $path/config-network >> $path/config
	rm $path/config-network

	if [ $? -ne 0 ]
	then
		echo "Failed to add configuration"
		return 1
	fi

	return 0
}

post_process() {
	local rootfs	;	rootfs=$1
	local release	;	release=$2
	local packages	;	packages=$3

	# Disable service startup
	cat > $rootfs/usr/sbin/policy-rc.d <<-EOF
		#!/bin/sh
		exit 101
		EOF
	chmod +x $rootfs/usr/sbin/policy-rc.d

	# If the container isn't running a native architecture, setup multiarch
	if [ -x "$(ls -1 ${rootfs}/usr/bin/qemu-*-static 2>/dev/null)" ]
	then
		dpkg_version=$(chroot $rootfs dpkg-query -W -f='${Version}' dpkg)
		if chroot $rootfs dpkg --compare-versions $dpkg_version ge "1.16.2"
		then
			chroot $rootfs dpkg --add-architecture ${hostarch}
		else
			mkdir -p ${rootfs}/etc/dpkg/dpkg.cfg.d
			echo "foreign-architecture ${hostarch}" >
			${rootfs}/etc/dpkg/dpkg.cfg.d/lxc-multiarch
		fi

		# Save existing value of MIRROR and SECURITY_MIRROR
		DEFAULT_MIRROR=$MIRROR
		DEFAULT_SECURITY_MIRROR=$SECURITY_MIRROR

		# Write a new sources.list containing both native and multiarch entries
		#+ > ${rootfs}/etc/apt/sources.list
		write_sourceslist $rootfs $arch "native"

		MIRROR=$DEFAULT_MIRROR
		SECURITY_MIRROR=$DEFAULT_SECURITY_MIRROR
		write_sourceslist $rootfs $hostarch "multiarch"

		# Finally update the lists and install upstart using the host
		#+ architecture
		HOST_PACKAGES="upstart:${hostarch} mountall:${hostarch} isc-dhcp-client:${hostarch}"
		chroot $rootfs apt-get update
		if chroot $rootfs dpkg -l iproute2 | grep -q ^ii
		then
			HOST_PACKAGES="$HOST_PACKAGES iproute2:${hostarch}"
		else
			HOST_PACKAGES="$HOST_PACKAGES iproute:${hostarch}"
		fi
		install_packages $rootfs $HOST_PACKAGES
	fi

	# Install Packages in container
	if [ -n "$packages" ]
	then
		local packages="`echo $packages | sed 's/,/ /g'`"
		echo "Installing packages: ${packages}"
		install_packages $rootfs $packages
	fi

	# Set initial timezone as on host
	if [ -f /etc/timezone ]
	then
		cat /etc/timezone > $rootfs/etc/timezone
		chroot $rootfs dpkg-reconfigure -f noninteractive tzdata
	elif [ -f /etc/sysconfig/clock ]
	then
		source /etc/sysconfig/clock
		echo $ZONE > $rootfs/etc/timezone
		chroot $rootfs dpkg-reconfigure -f noninteractive tzdata
	else
		echo "Timezone in container is not configured. Adjust it manually."
	fi

	# rmdir /dev/shm for containers that have /run/shm
	# I'm afraid of doing rm -rf $rootfs/dev/shm, in case it did
	# get bind mounted to the host's /run/shm.  So try to rmdir
	# it, and in case that fails move it out of the way.
	# NOTE: This can only be removed once 12.04 goes out of support
	if [ ! -L $rootfs/dev/shm ] && [ -e $rootfs/dev/shm ]
	then
		rmdir $rootfs/dev/shm 2>/dev/null || \
		mv $rootfs/dev/shm $rootfs/dev/shm.bak
		ln -s /run/shm $rootfs/dev/shm
	fi
	# Re-enable service startup
	rm $rootfs/usr/sbin/policy-rc.d
}

do_bindhome() {
	local rootfs	;	rootfs=$1
	local user	;	user=$2
	# copy /etc/passwd, /etc/shadow and /etc/group entries into container
	local pwd	;	pwd=`getent passwd $user` || {
		echo "Failed to copy password entry for $user"
		false
	}
	echo $pwd >> $rootfs/etc/passwd
	# make sure user's shell exists in the container
	local shell	;	shell=`echo $pwd | cut -d: -f 7`
	if [ ! -x $rootfs/$shell ]
	then
		echo "shell $shell for user $user was not found in the container."
		pkg=`dpkg -S $(readlink -m $shell) | cut -d ':' -f1`
		echo "Installing $pkg"
		install_packages $rootfs $pkg
	fi
	local shad	;	shad=`getent shadow $user`
	echo "$shad" >> $rootfs/etc/shadow
	# bind-mount the user's path into the container's /home
	local h	;	h=`getent passwd $user | cut -d: -f 6`
	mkdir -p $rootfs/$h
	# use relative path in container
	local h2	;	h2=${h#/}
	while [ ${h2:0:1} = "/" ]
	do
		h2=${h2#/}
	done
	echo "lxc.mount.entry = $h $h2 none bind 0 0" >> $path/config

	# Make sure the group exists in container
	grp=`echo $pwd | cut -d: -f 4`	# group number for $user
	grpe=`getent group $grp` || \
	return 0	# if host doesn't define grp, ignore in container
	chroot $rootfs getent group "$grpe" || echo "$grpe" >> $rootfs/etc/group
}

usage() {
	cat <<-EOF
		$1 -h|--help [-a|--arch] [-b|--bindhome <user>] [-d|--debug]
		   [-F | --flush-cache] [-r|--release <release>] [-v|--variant] [ -S | --auth-key <keyfile>]
		   [--rootfs <rootfs>] [--packages <packages>] [-u|--user <user>] [--password <password>]
		   [--mirror <url>] [--security-mirror <url>]
		release: the ubuntu release (e.g. xenial): defaults to host release on ubuntu, otherwise uses latest LTS
		variant: debootstrap variant to use (see debootstrap(8))
		bindhome: bind <user>'s home into the container
				  The ubuntu user will not be created, and <user> will have
				  sudo access.
		arch: the container architecture (e.g. amd64): defaults to host arch
		auth-key: SSH Public key file to inject into container
		packages: list of packages to add comma separated
		mirror,security-mirror: mirror for download and /etc/apt/sources.list
		EOF
	return 0
}

options=$(getopt -o a:b:hp:r:v:n:FS:du: -l arch:,bindhome:,help,path:,release:,\
variant:,name:,flush-cache,auth-key:,debug,rootfs:,packages:,user:,password:\
,mirror:,security-mirror: -- "$@")
if [ $? -ne 0 ]
then
	usage $(basename $0)
	exit 1
fi
eval set -- "$options"

release=jammy # Default to the last Ubuntu LTS release for non-Ubuntu systems
if [ -f /etc/lsb-release ]
then
	source /etc/lsb-release
	if [ "$DISTRIB_ID" = "Ubuntu" ]
	then
		release=$DISTRIB_CODENAME
	fi
fi

bindhome=

# Code taken from debootstrap
if [ -x /usr/bin/dpkg ] && /usr/bin/dpkg --print-architecture >/dev/null 2>&1
then
	arch=`/usr/bin/dpkg --print-architecture`
elif which udpkg >/dev/null 2>&1 && udpkg --print-architecture >/dev/null 2>&1
then
	arch=`/usr/bin/udpkg --print-architecture`
else
	arch=$(uname -m)
	if [ "$arch" = "i686" ]
	then
		arch="i386"
	elif [ "$arch" = "x86_64" ]
	then
		arch="amd64"
	elif [ "$arch" = "armv7l" ]
	then
		arch="armhf"
	elif [ "$arch" = "aarch64" ]
	then
		arch="arm64"
	elif [ "$arch" = "ppc64le" ]
	then
		arch="ppc64el"
	fi
fi

debug=0
hostarch=$arch
flushcache=0
packages=""
user="ubuntu"
password="ubuntu"

while true
do
	case "$1" in
	-h|--help)			usage "$0" && exit 0;;
	--rootfs)			rootfs="$2"			;	shift 2;;
	-p|--path)			path="$2"			;	shift 2;;
	-n|--name)			name="$2"			;	shift 2;;
	-u|--user)			user=$2				;	shift 2;;
	--password)			password="$2"		;	shift 2;;
	-F|--flush-cache)	flushcache=1		;	shift 1;;
	-r|--release)		release=$2			;	shift 2;;
	-v|--variant)		variant=$2			;	shift 2;;
	--packages)			packages="$2"		;	shift 2;;
	-b|--bindhome)		bindhome="$2"		;	shift 2;;
	-a|--arch)			arch="$2"			;	shift 2;;
	-S|--auth-key)		auth_key="$2"		;	shift 2;;
	-d|--debug)			debug=1				;	shift 1;;
	--mirror)			MIRROR="$2"			;	shift 2;;
	--security-mirror)	SECURITY_MIRROR=$2	;	shift 2;;
	--)					shift 1				;	break ;;
	*)											break ;;
	esac
done

if [ $debug -eq 1 ]
then
	set -x
fi

if [ -n "$bindhome" ]
then
	pwd=`getent passwd $bindhome`
	if [ $? -ne 0 ]
	then
		echo "Error: no password entry found for $bindhome"
		exit 1
	fi
fi

if [ "$arch" = "i686" ]
then
	arch=i386
fi

arch_not_on_arch(){
	echo "can't create $arch container on $hostarch"
	exit 1
}

if [ $hostarch = "i386" -a $arch = "amd64" ]
then
	arch_not_on_arch
fi

if [ $hostarch = "armhf" -o $hostarch = "armel" -o $hostarch = "arm64" ] && \
[ $arch != "armhf" -a $arch != "armel" -a $arch != "arm64" ]
then
	arch_not_on_arch
fi

if [ $arch = "arm64" ] && [ $hostarch != "arm64" ]
then
	arch_not_on_arch
fi

if [ $hostarch = "powerpc" -a $arch != "powerpc" ]
then
	arch_not_on_arch
fi

which debootstrap >/dev/null 2>&1 || {
	echo "'debootstrap' command is missing" >&2
	false
}

if [ -z "$path" ]
then
	echo "'path' parameter is required"
	exit 1
fi

# detect rootfs
config="$path/config"
# if $rootfs exists here, it was passed in with --rootfs
if [ -z "$rootfs" ]
then
	if grep -q '^lxc.rootfs.path' $config 2>/dev/null
	then
		rootfs=$(awk -F= '/^lxc.rootfs.path =/{ print $2 }' $config)
	else
		rootfs=$path/rootfs
	fi
fi

install_ubuntu $rootfs $release $flushcache $LXC_CACHE_PATH
if [ $? -ne 0 ]
then
	echo "failed to install ubuntu $release"
	exit 1
fi

configure_ubuntu $rootfs $name $release $user $password
if [ $? -ne 0 ]
then
	echo "failed to configure ubuntu $release for a container"
	exit 1
fi

copy_configuration $path $rootfs $name $arch $release
if [ $? -ne 0 ]
then
	echo "failed write configuration file"
	exit 1
fi

post_process $rootfs $release $trim_container $packages

if [ -n "$bindhome" ]
then
	do_bindhome $rootfs $bindhome
	finalize_user $bindhome
else
	finalize_user $user
fi

echo ""
echo "##"
if [ -n "$bindhome" ]
then
	echo "# Log in as user $bindhome"
else
	echo "# The default user is '$user' with password '$password'!"
	echo "# Use the 'sudo' command to run tasks as root in the container."
fi
echo "##"
echo ""
