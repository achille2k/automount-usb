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

usage()
{
    ${log} "Usage: $0 {add|remove} device_name (e.g. sr0)"
    exit 1
}

if [[ $# -ne 2 ]]; then
    usage
fi


ACTION=$1
DEVBASE=$2
DEVICE="/dev/${DEVBASE}"
NUMBER=$(echo "${DEVBASE}" | sed 's/[^0-9]*//g')

echo ${DEVBASE}

# See if this drive is already mounted, and if so where
MOUNT_POINT=$(mount | grep ${DEVICE} | awk '{ print $3 }')


do_mount()
{
	if [[ -n ${MOUNT_POINT} ]]; then
			${log} "Warning: ${DEVICE} is already mounted at ${MOUNT_POINT}"
			exit 1
	fi

	DEV_LABEL="cdrom"

	if [ ${NUMBER} -gt 0 ]; then
		DEV_LABEL+="${NUMBER}"
	fi

	MOUNT_POINT="/media/${DEV_LABEL}"

	${log} "Mount point: ${MOUNT_POINT}"

	mkdir -p ${MOUNT_POINT}

	if ! mount ${DEVICE} ${MOUNT_POINT}; then
		${log} "Error mounting ${DEVICE} (status = $?)"
		rmdir "${MOUNT_POINT}"
		exit 1
	else
		# Track the mounted drives
		echo "${MOUNT_POINT}:${DEVBASE}" | cat >> "/var/log/cdrom-mount.track" 
	fi

	${log} "Mounted ${DEVICE} at ${MOUNT_POINT}"
}

do_unmount()
{
    if [[ -z ${MOUNT_POINT} ]]; then
        ${log} "Warning: ${DEVICE} is not mounted"
    else
        umount -l ${DEVICE}
	${log} "Unmounted ${DEVICE} from ${MOUNT_POINT}"
        /bin/rmdir "${MOUNT_POINT}"
        sed -i.bak "\@${MOUNT_POINT}@d" /var/log/usb-mount.track
    fi


}

case "${ACTION}" in
    add)
        do_mount
        ;;
    remove)
        do_unmount
        ;;
    *)
        usage
        ;;
esac