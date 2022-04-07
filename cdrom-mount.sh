#!/usr/bin/env bash
# If you are executing this script in cron with a restricted environment,
# modify the shebang to specify appropriate path; /bin/bash in most distros.
# And, also if you aren't comfortable using(abuse?) env command.

# This script is based on https://serverfault.com/a/767079 posted
# by Mike Blackwell, modified to our needs. Credits to the author.

# This script is called from systemd unit file to mount or unmount
# a CDROM drive.

PATH="$PATH:/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin:/bin:/sbin"
log="logger -t cdrom-mount.sh -s "

DEVBASE=$1
DEVICE="/dev/${DEVBASE}"

# See if this drive is already mounted, and if so where
MOUNT_POINT=$(mount | grep ${DEVICE} | awk '{ print $3 }')

DEV_LABEL=""

if [[ -n ${MOUNT_POINT} ]]; then
        ${log} "Warning: ${DEVICE} is already mounted at ${MOUNT_POINT}"
        exit 1
fi

# Get info for this drive: $ID_FS_LABEL and $ID_FS_TYPE
eval $(blkid -o udev ${DEVICE} | grep -i -e "ID_FS_LABEL" -e "ID_FS_TYPE")

# Figure out a mount point to use
LABEL=${ID_FS_LABEL}
if grep -q " /media/${LABEL} " /etc/mtab; then
	# Already in use, make a unique one
	LABEL+="-${DEVBASE}"
fi
DEV_LABEL="${LABEL}"

# Use the device name in case the drive doesn't have label
if [ -z ${DEV_LABEL} ]; then
	DEV_LABEL="${DEVBASE}"
fi

MOUNT_POINT="/media/${DEV_LABEL}"

${log} "Mount point: ${MOUNT_POINT}"

mkdir -p ${MOUNT_POINT}

# Global mount options 
OPTS="ro"

# File system type specific mount options
#if [[ ${ID_FS_TYPE} == "vfat" ]]; then
#	OPTS+=",users,gid=100,umask=000,shortname=mixed,utf8=1,flush"
#fi

if ! mount -o ${OPTS} ${DEVICE} ${MOUNT_POINT}; then
	${log} "Error mounting ${DEVICE} (status = $?)"
	rmdir "${MOUNT_POINT}"
	exit 1
else
	# Track the mounted drives
	echo "${MOUNT_POINT}:${DEVBASE}" | cat >> "/var/log/cdrom-mount.track" 
fi

${log} "Mounted ${DEVICE} at ${MOUNT_POINT}"