#Resize drive when requested
if [ -d /home/.resizerootfs ] ; then
	
	dpkg-reconfigure openssh-server
        
	ROOT_PART=$(cat /proc/cmdline | sed 's/ /\n/g' | grep root= | awk -F 'root=' '{print $2}'| awk -F '/' '{print $3}')

	ROOT_DEV=${ROOT_PART%p*}

  	PART_NUM=${ROOT_PART#${ROOT_DEV}p}

  	LAST_PART_NUM=$(parted /dev/${ROOT_DEV} -ms unit s p | tail -n 1 | cut -f 1 -d:)
	  
  if [ $LAST_PART_NUM -ne $PART_NUM ]; then
    echo "$ROOT_PART is not the last partition. Don't know how to expand"
  fi

  # Get the starting offset of the root partition
  PART_START=$(parted /dev/${ROOT_DEV} -ms unit s p | grep "^${PART_NUM}" | cut -f 2 -d: | sed 's/[^0-9]//g')
  [ "$PART_START" ] || return 1
  # Return value will likely be error for fdisk as it fails to reload the
  # partition table because the root fs is mounted
  fdisk /dev/${ROOT_DEV} <<EOF
p
d
$PART_NUM
n
p
$PART_NUM
$PART_START

p
w
EOF
  ASK_TO_REBOOT=1

  # now set up an init.d script
cat <<EOF > /etc/init.d/resize2fs_once &&
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 3
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO

. /lib/lsb/init-functions

case "\$1" in
  start)
    log_daemon_msg "Starting resize2fs_once" &&
    resize2fs /dev/$ROOT_PART &&
    update-rc.d resize2fs_once remove &&
    rm /etc/init.d/resize2fs_once &&
    log_end_msg \$?
    ;;
  *)
    echo "Usage: \$0 start" >&2
    exit 3
    ;;
esac
EOF
  chmod +x /etc/init.d/resize2fs_once &&
  update-rc.d resize2fs_once defaults &&
  echo "Root partition has been resized.\nThe filesystem will be enlarged upon the next reboot"
  rmdir /home/.resizerootfs
  mkdir /boot/dtbs/
  mkdir /boot/dtbs/overlays
  systemctl reboot
fi

