#!/bin/bash

NAME=nbbackup
ETC=/etc/$NAME
SHARE=/usr/share/$NAME
CONFIG=$ETC/$NAME.conf
FUNCTIONS=$SHARE/functions.inc.sh

echo
echo "Nick Bolton's Backup Script"
echo "Copyright (C)  Nick Bolton 2009"
echo "http://code.google.com/p/nbbackup/"
echo

if [ ! -f $CONFIG ]; then
  echo "Missing file: $CONFIG"
  echo "The config file hasn't been created."
  echo "See $ETC/$NAME.conf.example for an example."
  exit 1
fi

if [ ! -f $FUNCTIONS ]; then
  echo "Missing file: $FUNCTIONS"
  echo "The program is not installed correctly."
  exit 1
fi

# Include config variables
. $CONFIG

# Include functions
. $FUNCTIONS

if [ ! -f $DRIVE_FILE ]; then
  echo "Missing file: $DRIVE_FILE"
  echo "See $ETC/drives.conf.example for an example."
  exit 1
fi

# Main program starts here
main "${@}"
