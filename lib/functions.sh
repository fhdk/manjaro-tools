#!/bin/bash

shopt -s extglob

# generated from util-linux source: libmount/src/utils.c
declare -A pseudofs_types=([anon_inodefs]=1
                           [autofs]=1
                           [bdev]=1
                           [binfmt_misc]=1
                           [cgroup]=1
                           [configfs]=1
                           [cpuset]=1
                           [debugfs]=1
                           [devfs]=1
                           [devpts]=1
                           [devtmpfs]=1
                           [dlmfs]=1
                           [fuse.gvfs-fuse-daemon]=1
                           [fusectl]=1
                           [hugetlbfs]=1
                           [mqueue]=1
                           [nfsd]=1
                           [none]=1
                           [pipefs]=1
                           [proc]=1
                           [pstore]=1
                           [ramfs]=1
                           [rootfs]=1
                           [rpc_pipefs]=1
                           [securityfs]=1
                           [sockfs]=1
                           [spufs]=1
                           [sysfs]=1
                           [tmpfs]=1)

# generated from: pkgfile -vbr '/fsck\..+' | awk -F. '{ print $NF }' | sort
declare -A fsck_types=([cramfs]=1
                       [exfat]=1
                       [ext2]=1
                       [ext3]=1
                       [ext4]=1
                       [ext4dev]=1
                       [jfs]=1
                       [minix]=1
                       [msdos]=1
                       [reiserfs]=1
                       [vfat]=1
                       [xfs]=1)

# out() { printf "$1 $2\n" "${@:3}"; }
# error() { out "==> ERROR:" "$@"; } >&2
# msg() { out "==>" "$@"; }
# msg2() { out "  ->" "$@";}
# die() { error "$@"; exit 1; }

# Avoid any encoding problems
export LANG=C

# check if messages are to be printed using color
unset ALL_OFF BOLD BLUE GREEN RED YELLOW
if [[ -t 2 ]]; then
	# prefer terminal safe colored and bold text when tput is supported
	if tput setaf 0 &>/dev/null; then
		ALL_OFF="$(tput sgr0)"
		BOLD="$(tput bold)"
		BLUE="${BOLD}$(tput setaf 4)"
		GREEN="${BOLD}$(tput setaf 2)"
		RED="${BOLD}$(tput setaf 1)"
		YELLOW="${BOLD}$(tput setaf 3)"
	else
		ALL_OFF="\e[1;0m"
		BOLD="\e[1;1m"
		BLUE="${BOLD}\e[1;34m"
		GREEN="${BOLD}\e[1;32m"
		RED="${BOLD}\e[1;31m"
		YELLOW="${BOLD}\e[1;33m"
	fi
fi
readonly ALL_OFF BOLD BLUE GREEN RED YELLOW

plain() {
	local mesg=$1; shift
	printf "${BOLD}    ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg() {
	local mesg=$1; shift
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg2() {
	local mesg=$1; shift
	printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

warning() {
	local mesg=$1; shift
	printf "${YELLOW}==> WARNING:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

error() {
	local mesg=$1; shift
	printf "${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

stat_busy() {
	local mesg=$1; shift
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}...${ALL_OFF}" >&2
}

stat_done() {
	printf "${BOLD}done${ALL_OFF}\n" >&2
}

setup_workdir() {
	[[ -z $WORKDIR ]] && WORKDIR=$(mktemp -d --tmpdir "${0##*/}.XXXXXXXXXX")
}

cleanup() {
	[[ -n $WORKDIR ]] && rm -rf "$WORKDIR"
	[[ $1 ]] && exit $1
}

abort() {
	msg 'Aborting...'
	cleanup 0
}

trap_abort() {
	trap - EXIT INT QUIT TERM HUP
	abort
}

trap_exit() {
	trap - EXIT INT QUIT TERM HUP
	cleanup
}

die() {
	error "$*"
	cleanup 1
}

trap 'trap_abort' INT QUIT TERM HUP
trap 'trap_exit' EXIT



ignore_error() {
  "$@" 2>/dev/null
  return 0
}

track_mount() {
  if [[ -z $CHROOT_ACTIVE_MOUNTS ]]; then
    CHROOT_ACTIVE_MOUNTS=()
    trap 'chroot_umount' EXIT
  fi

  mount "$@" && CHROOT_ACTIVE_MOUNTS=("$2" "${CHROOT_ACTIVE_MOUNTS[@]}")
}

mount_conditionally() {
  local cond=$1; shift
  if eval "$cond"; then
    track_mount "$@"
  fi
}

api_fs_mount() {
  mount_conditionally "! mountpoint -q '$1'" "$1" "$1" --bind &&
  track_mount proc "$1/proc" -t proc -o nosuid,noexec,nodev &&
  track_mount sys "$1/sys" -t sysfs -o nosuid,noexec,nodev,ro &&
  ignore_error mount_conditionally "[[ -d '$1/sys/firmware/efi/efivars' ]]" \
      efivarfs "$1/sys/firmware/efi/efivars" -t efivarfs -o nosuid,noexec,nodev &&
  track_mount udev "$1/dev" -t devtmpfs -o mode=0755,nosuid &&
  track_mount devpts "$1/dev/pts" -t devpts -o mode=0620,gid=5,nosuid,noexec &&
  track_mount shm "$1/dev/shm" -t tmpfs -o mode=1777,nosuid,nodev &&
  track_mount run "$1/run" -t tmpfs -o nosuid,nodev,mode=0755 &&
  track_mount tmp "$1/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid
}

api_fs_mount2() {
	mount_conditionally "! mountpoint -q '$1'" "$1" "$1" --bind &&
	track_mount proc "$1/proc" -t proc -o nosuid,noexec,nodev &&
	track_mount sys "$1/sys" -t sysfs -o nosuid,noexec,nodev,ro &&
	track_mount udev "$1/dev" -t devtmpfs -o mode=0755,nosuid &&
	track_mount devpts "$1/dev/pts" -t devpts -o mode=0620,gid=5,nosuid,noexec &&
	track_mount shm "$1/dev/shm" -t tmpfs -o mode=1777,nosuid,nodev &&
	track_mount run "$1/run" -t tmpfs -o nosuid,nodev,mode=0755 &&
	track_mount tmp "$1/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid
	track_mount /etc/resolv.conf "$1/etc/resolv.conf" --bind
	track_mount ${cache_dirs[0]} "$1/${cache_dirs[0]}" --bind
}

chroot_umount() {
  umount "${CHROOT_ACTIVE_MOUNTS[@]}"
}

fstype_is_pseudofs() {
  (( pseudofs_types["$1"] ))
}

fstype_has_fsck() {
  (( fsck_types["$1"] ))
}

# in_array() {
#   local i
#   for i in "${@:2}"; do
#     [[ $1 = "$i" ]] && return
#   done
# }
##
#  usage : in_array( $needle, $haystack )
# return : 0 - found
#          1 - not found
##
in_array() {
	local needle=$1; shift
	local item
	for item in "$@"; do
		[[ $item = $needle ]] && return 0 # Found
	done
	return 1 # Not Found
}

valid_number_of_base() {
  local base=$1 len=${#2} i=

  for (( i = 0; i < len; i++ )); do
    { _=$(( $base#${2:i:1} )) || return 1; } 2>/dev/null
  done

  return 0
}

mangle() {
  local i= chr= out=

  unset {a..f} {A..F}

  for (( i = 0; i < ${#1}; i++ )); do
    chr=${1:i:1}
    case $chr in
      [[:space:]\\])
        printf -v chr '%03o' "'$chr"
        out+=\\
        ;;
    esac
    out+=$chr
  done

  printf '%s' "$out"
}

unmangle() {
  local i= chr= out= len=$(( ${#1} - 4 ))

  unset {a..f} {A..F}

  for (( i = 0; i < len; i++ )); do
    chr=${1:i:1}
    case $chr in
      \\)
        if valid_number_of_base 8 "${1:i+1:3}" ||
            valid_number_of_base 16 "${1:i+1:3}"; then
          printf -v chr '%b' "${1:i:4}"
          (( i += 3 ))
        fi
        ;;
    esac
    out+=$chr
  done

  printf '%s' "$out${1:i}"
}

dm_name_for_devnode() {
  read dm_name <"/sys/class/block/${1#/dev/}/dm/name"
  if [[ $dm_name ]]; then
    printf '/dev/mapper/%s' "$dm_name"
  else
    # don't leave the caller hanging, just print the original name
    # along with the failure.
    print '%s' "$1"
    error 'Failed to resolve device mapper name for: %s' "$1"
  fi
}

##
#  usage : get_full_version( [$pkgname] )
# return : full version spec, including epoch (if necessary), pkgver, pkgrel
##
get_full_version() {
	# set defaults if they weren't specified in buildfile
	pkgbase=${pkgbase:-${pkgname[0]}}
	epoch=${epoch:-0}
	if [[ -z $1 ]]; then
		if [[ $epoch ]] && (( ! $epoch )); then
			echo $pkgver-$pkgrel
		else
			echo $epoch:$pkgver-$pkgrel
		fi
	else
		for i in pkgver pkgrel epoch; do
			local indirect="${i}_override"
			eval $(declare -f package_$1 | sed -n "s/\(^[[:space:]]*$i=\)/${i}_override=/p")
			[[ -z ${!indirect} ]] && eval ${indirect}=\"${!i}\"
		done
		if (( ! $epoch_override )); then
			echo $pkgver_override-$pkgrel_override
		else
			echo $epoch_override:$pkgver_override-$pkgrel_override
		fi
	fi
}
