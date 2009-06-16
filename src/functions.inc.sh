# Include file, used by nbbackup.sh

PID_BASE=/var/run/nbbackup
PID=$PID_BASE.pid
RSYNC_PID=$PID_BASE.rsync.pid

# Log not set in config? Use default.
if [ "$LOG" == "" ]; then
  LOG=/var/log/nbbackup.log
fi

function setupTrap {

  # Exit with error on INT or TERM
  trap "safeExit 1" SIGINT SIGTERM

  # Exit with no error, on normal EXIT
  trap safeExit EXIT

} # setupTrap

function removeTrap {

  trap - SIGINT SIGTERM EXIT

} # removeTrap

function lockProcess {

  if [ -f $PID ]; then
    echo "Already running or improper exit on PID: `cat $PID`"
    echo "Remove $PID to continue."
    
    # Remove trap and exit (so safeExit not called)
    removeTrap
    exit 1
  fi

  echo $$ > $PID

} # lockProcess

function unlockProcess {

  rm $PID

} # unlockProcess

function cleanup {

  # First, stop rsync from using backup drive.
  if [ -f $RSYNC_PID ]; then

    RSYNC_PID_VALUE=`cat $RSYNC_PID`

    echo "Killing rsync process ($RSYNC_PID_VALUE)..."
    kill $RSYNC_PID_VALUE
  
    while ps -p $RSYNC_PID_VALUE > /dev/null; do
      echo "Waiting for rsync to die..."
      sleep 1
    done

    rm $RSYNC_PID
  fi

  # After rsync has been killed, now unmount.
  if [ $(mount | grep $TARGET | wc -l) != 0 ]; then
    # Ensure backup drive not left mounted.
    unmountBackup
  fi

} # cleanup

function safeExit {

  if [ $1 > 0 ]; then
    echo "Exiting with code: $1"
    cleanup
  fi

  # Clean up exit.
  unlockProcess
  removeTrap

  if [ $1 > 0 ]; then
    echo "Done, but with errors."
  else
    echo "Done."
  fi

  exit $1

} # safeExit

function checkRoot {

  if [ $(whoami) != "root" ]; then
    echo "Must be run as root."
    exit 1
  fi

} # checkRoot

function testDrive {

  mountBackup
  if [ "$?" != 0 ]; then exit 1; fi

  unmountBackup
  if [ "$?" != 0 ]; then exit 1; fi  

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

  if [ $CHECK == 1 ]; then
    echo "Checking backup drive..."
    fsck -aMT /dev/disk/by-id/$DRIVE 2>&1 >> $LOG
  
    if [ $? != 0 ]; then
      echo "Check failed, aborting."
      exit 1
    fi
  fi

  if [ -d $TARGET ]; then
    echo "Removing exiting mount target..."
    rm -rv $TARGET
  fi

  echo "Mounting backup drive..."
  mkdir $TARGET
  mount /dev/disk/by-id/$DRIVE $TARGET
  
  if [ $? != 0 ]; then
    echo "Mount failed, aborting."
    exit 1
  fi

} #mountBackup

function unmountBackup {

  echo "Unmounting backup drive..."
  umount -l $TARGET

  if [ $? != 0 ]; then
    echo "Unmount failed, aborting."
    return 1
  fi

  rm -r $TARGET

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
 
  echo "Starting files backup using rsync..."
  rsync -av --delete $RS_SOURCE $RS_TARGET 2>&1 >> $LOG & > /dev/null

  # Store pid so we can kill it on trap
  echo $! > $RSYNC_PID

  echo "Waiting for rsync to finish..."
  wait

  unmountBackup

} # filesBackup

function printUsage {

  echo "$0 [OPTIONS...]"
  echo "-f   Backup using rsync (exact mirror)"
  echo "-i   Backup using partimage (overwrites)"
  echo "-m   Just mount backup drive"
  echo "-u   Unmount backup drive (if mounted)"
  echo "-t   Test for backup drives"
  echo "-c   Check and auto-fix backup drive"
  echo "-b   Run in background (like a daemon)"
  echo "-h   Shows help/usage (default)"

} # printUsage


function main {

  checkRoot
  setupTrap
  lockProcess

  while getopts "fimutcbh-:" param; do
    case $param in
      c) CHECK=1 ;;
      i) ARG_IMAGE=1 ;;
      f) ARG_FILES=1 ;;
      m) ARG_MOUNT=1 ;;
      u) ARG_UNMOUNT=1 ;;
      t) ARG_TEST=1 ;;
      b) ARG_BACKGROUND=1 ;;
      -) ;;
      *) printUsage; exit 0 ;;
    esac
  done

  # Show usage when no args.
  if [ $# == 0 ]; then
    echo "No args specified, showing usage."
    printUsage
    exit 0
  fi

  for ARG in "$@"; do
    if [ "$ARG" == "--forked" ]; then
      ARG_FORKED=1
    fi
    if [ "$ARG" == "--debug-sleep" ]; then
      ARG_DEBUG_SLEEP=1
    fi
  done

  if [ $ARG_BACKGROUND ] && [ ! $ARG_FORKED ]; then

    # Remove trap and pid file before re-launching.
    removeTrap
    unlockProcess

    # Re-launch with --forked to stop infinate loop.
    CMD="$0 $@ --forked"
    $CMD 2>&1 >> $LOG & > /dev/null

    echo "Writing to log file: $LOG"
    echo "Running in background with PID: $!"
    exit 0
  fi

  # Handy for testing "run in background".
  if [ $ARG_DEBUG_SLEEP ]; then
    echo "Sleeping for 10 seconds..."
    sleep 10
    exit 1
  fi

  if [ $ARG_IMAGE ]; then
    imageBackup
  elif [ $ARG_FILES ]; then
    filesBackup
  elif [ $ARG_MOUNT ]; then
    mountBackup
  elif [ $ARG_UNMOUNT ]; then
    unmountBackup
  elif [ $ARG_TEST ]; then
    testDrive
  fi

  exit 0

} #main
