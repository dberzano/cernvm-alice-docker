#!/bin/bash

# this is not truly in userspace, but it uses unionfs-fuse in place of aufs

cvm_ro_prefix='/cvmfs/cernvm-prod.cern.ch/cvm3'

overlay_prefix="/tmp/overlay_$USER/cvm3"
overlay_ro="$cvm_ro_prefix"
overlay_rw="${overlay_prefix}/rw"
overlay_mnt="${overlay_prefix}/mnt"

# aufs or unionfs
overlay_method='aufs'


cat /proc/mounts | grep -q "^unionfs-fuse ${overlay_mnt} "
if [[ $? == 0 ]] ; then
  echo 'umounting first (unionfs)'
  set -e
  sudo fusermount -u "$overlay_mnt"
  sudo rm -rf "$overlay_prefix"
  set +e
fi

cat /proc/mounts | grep -q " ${overlay_mnt} aufs "
if [[ $? == 0 ]] ; then
  echo 'umounting first (aufs)'
  set -e
  sudo umount "$overlay_mnt"
  sudo rm -rf "$overlay_prefix"
  set +e
fi

if [[ $1 == -u ]] ; then
  echo 'only umount requested: exiting now'
  exit 0
fi

mkdir -p "$overlay_rw" "$overlay_mnt"

if [[ $overlay_method == unionfs ]] ; then
  # branches: higher level to lower level, higher has priority
  set -e
  sudo unionfs-fuse -o cow -o allow_other "${overlay_rw}=RW:${overlay_ro}=RO" "$overlay_mnt"
elif [[ $overlay_method == aufs ]] ; then
  set -e
  sudo mount -t aufs -o br="${overlay_rw}:${overlay_ro}" none "$overlay_mnt"
fi

set +e

echo "ok, mounted on: ${overlay_mnt}"

cat /proc/mounts | grep "unionfs-fuse ${overlay_mnt}"
