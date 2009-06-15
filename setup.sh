#!/bin/bash

NAME=nbbackup
ETC=/etc/$NAME
SHARE=/usr/share/$NAME
BIN=/usr/bin/nbbackup
CONFIG=$ETC/nbbackup.conf

function checkRoot {

  if [ $(whoami) != "root" ]; then
    echo "Must be run as root."
    exit 1
  fi

} # checkRoot

function install {

  checkRoot

  if [ ! -d $ETC ]; then
    mkdir $ETC
  fi

  echo -e "\nCopying config files..."
  cp -vf conf/* $ETC/ 

  if [ ! -d $SHARE ]; then
    mkdir $SHARE
  fi

  echo -e "\nCopying script files..."
  cp -vf src/* $SHARE/

  echo -e "\nCreating bin link..."
  ln -sfv $SHARE/nbbackup.sh $BIN

  echo -e "\nInstall complete!"
  echo -e "Remember to create $CONFIG\n"

} # install

function uninstall {

  checkRoot

  echo
  read -p "Remove scripts and config files? [Y/n] " CONFIRM

  if [ "$CONFIRM" == N ] || [ "$CONFIRM" == n ]; then
    exit 1;
  fi

  echo -e "\nRemoving config files..."
  rm -rv $ETC

  echo -e "\nRemoving script files..."
  rm -rv $SHARE

  echo -e "\nRemoving bin link..."
  rm -v $BIN

  echo -e "\nUninstall complete!\n"

} # uninstall

function printUsage {

  echo "$0 -i|-u|-h"
  echo "-i	Install"
  echo "-u	Uninstall"
  echo "-h	Show help/usage"

} # printUsage

function main {

  while getopts "iuh" param; do
    case $param in
      i) install; exit 0 ;;
      u) uninstall; exit 0;;
      *) printUsage; exit 0 ;;
    esac
  done

  # Show usage when no args.
  if [ $# -ne 1 ]; then
    echo "No args specified, showing usage."
    printUsage
    exit 0
  fi

} # main

main "${@}"
