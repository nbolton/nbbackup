# Include file, used by /usr/share/backup/backup.sh

function checkRoot {

  if [ $(whoami) != "root" ]; then
    echo "Must be run as root."
    exit 1
  fi

} # checkRoot

function testDrive {

  mountBackup
  unmountBackup

} # testDrive

function selectDrive {

  echo "Finding backup drive..."

  for DRIVE_NAME in `cat $DRIVE_FILE`
  do
    if [ $(ls /dev/disk/by-id | grep $DRIVE_NAME | wc -l) != 0 ]; then
      DRIVE="$DRIVE_NAME"
    fi
  done

  if [ "$DRIVE" == "" ]; then
    echo "No backup drives found."
    exit 1
  else
    echo "Found: $DRIVE"
  fi 

} # selectDrive

function mountBackup {

  if [ $(mount | grep $TARGET | wc -l) != 0 ]; then
    echo "Unmounting existing backup drive..."
    umount -l $TARGET
  fi

  selectDrive

  if [ CHECK == TRUE ]; then
    echo "Checking backup drive..."
    fsck -aMT /dev/disk/by-id/$DRIVE
  
    if [ $? != 0 ]; then
      echo "Check failed, aborting."
      exit 1
    fi
  fi

  echo "Mounting backup drive..."
  mount /dev/disk/by-id/$DRIVE $TARGET
  
  if [ $? != 0 ]; then
    echo "Mount failed, aborting."
    exit 1
  fi

} #mountBackup

function unmountBackup {

  echo "Unmounting backup drive..."
  umount -l $TARGET

} #unmountBackup

function imageBackup {

  mountBackup

  echo "Stopping services using storage drive..."
  $SAMBA stop
  $NFS stop

  echo "Wait for services to stop using storage..."
  sleep 5

  if [ $(fuser -m $PI_DRIVE | wc -l) != 0 ]; then

    echo "Cannot unmount storage drive, because it is in use."
    fuser -m $PI_DRIVE
    exit 1

  else

    echo "Unmount so partimage can copy..."
    umount $PI_DRIVE

    echo "Running partimage with options:"
    echo "  b (batch), d (no description), o (overwrite),"
    echo "  f3 (quit on success)"
    partimage -bdo -f3 save $PI_DRIVE $PI_IMAGE

    echo "Re-mounting storage..."
    mount $PI_DRIVE $PI_REMOUNT

  fi # fuser

  echo "Restart services using storage..."
  $SAMBA start
  $NFS start

  unmountBackup

} # imageBackup

function filesBackup { 

  mountBackup
 
  echo "Syncronizing storage drive with backup drive..."
  rsync -av --delete $RS_SOURCE $RS_TARGET

  unmountBackup

} # filesBackup

function printUsage {

  echo "$0 [-c] ..."
  echo "-c	Check and auto-fix backup drive"
  echo "-i	Backup using partimage (overwrites)"
  echo "-f 	Backup using rsync (exact mirror)"
  echo "-m	Just mount backup drive"
  echo "-u	Unmount backup drive (if mounted)"
  echo "-t	Test for backup drives"
  echo "-h	Shows help / usage (default)"

} # printUsage

function main {

  checkRoot

  while getopts "cifmuth" param; do
    case $param in
      c) CHECK=TRUE ;;
      i) imageBackup; exit 0 ;;
      f) filesBackup; exit 0 ;;
      m) mountBackup; exit 0 ;;
      u) unmountBackup; exit 0 ;;
      t) testDrive; exit 0 ;;
      *) printUsage; exit 0 ;;
    esac
  done

  # Show usage when no args.
  if [ $# -ne 1 ]; then
    echo "No args specified, showing usage."
    printUsage
    exit 0
  fi

} #main
