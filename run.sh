#!/bin/bash

# Launch CernVM in a Docker container

# Reset overlay first
$(dirname "$0")/overlay.sh

#cvm_prefix='/cvmfs/cernvm-prod.cern.ch/cvm3'
#cvm_prefix='/tmp/overlay/cvm3/mnt'
cvm_prefix="/tmp/overlay_${USER}/cvm3/mnt"
#cvm_docker_image='dberzano/cernvm:0.1'
cvm_docker_image='dberzano/cernvm'

bind_mounts=''

#excluded=( cgroup dev proc selinux sys tmp )

# cvm ro
#excluded=( dev proc tmp )

# cvm rw
excluded=( dev proc )

cwd="$PWD"
cd "$cvm_prefix"

for d in * ; do

  if [[ -d $d ]] ; then

    if [[ $d == 'etc' ]] ; then

      # /etc is a special case: we will create the actual one at boot time
      echo "bind[RO]> ${d} -> /.etc.cvmro"
      bind_mounts="${bind_mounts} -v ${cvm_prefix}/${d}:/.etc.cvmro:ro"

    else

      # unless explicitly excluded, mount it overlaid
      is_excluded=0
      for e in ${excluded[@]} ; do
        if [[ $d == $e ]] ; then
          is_excluded=1
          break 
        fi
      done

      if [[ $is_excluded == 0 ]] ; then
        echo "bind[RW]> ${d} -> /${d}"
        bind_mounts="${bind_mounts} -v ${cvm_prefix}/${d}:/${d}"
      fi

    fi

  elif [[ -f $d ]] ; then
    # skip files
    echo "skip[FI]> ${d}"
  else
    # skip all the rest
    echo "skip[??]> ${d}"
  fi

done

cd "$cwd"

exec docker run -t -i --rm $bind_mounts "$cvm_docker_image" "$@"
