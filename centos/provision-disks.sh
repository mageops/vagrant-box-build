#!/usr/bin/env bash

set -eu

log_step() { local NAME="$1"; shift; echo -en "\n  * $NAME: " >&2;  printf "%q " "$@" >&2; echo >&2; "$@" ; }

grow_root() {
  if growpart --update auto /dev/sda 1 ; then
    log_step "Grow root disk XFS filesystem" \
      xfs_growfs /dev/sda1
  fi
}

log_step "Grow the root disk partition" \
  grow_root

if [ -b /dev/sdb ] && [ -z "$(swapon --show --raw /dev/sdb)" ] ; then 
  log_step "Make swap on swap disk" \
    mkswap -L "SWAP" /dev/sdb

  log_step "Activate swap disk" \
    swapon /dev/sdb
fi