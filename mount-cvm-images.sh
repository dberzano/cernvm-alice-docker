#!/bin/bash

# Where was CernVM mounted?
cvm_root_prefix='/cvmfs/cernvm-prod.cern.ch/cvm3'

# Docker var dir
docker_prefix='/var/lib/docker'

# AUFS diffs
diffs_prefix="${docker_prefix}/aufs/diff"

# File name used as CernVM Placeholder
cvm_placeholder='THIS_IS_A_CERNVM_MOUNT_POINT'

exec 3< <( find "$diffs_prefix" -mindepth 2 -maxdepth 2 -name $cvm_placeholder )

while read -u3 cvm_mnt ; do

  cvm_mnt="$( dirname "$cvm_mnt" )"

  echo "$cvm_root_prefix -> $cvm_mnt"
  mount --bind "$cvm_root_prefix" "$cvm_mnt"

done
