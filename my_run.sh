#!/bin/bash
prog_dir="$( dirname "$0" )"
prog_dir="$( cd "$prog_dir" ; pwd )"

#exec "${prog_dir}/docker-cernvm" \
#  --tag pippo \
#  --opts "-i -t -v /cvmfs/alice.cern.ch:/cvmfs/alice.cern.ch -v ${prog_dir}/condor-configure:/condor-configure" \
#  run

ncpus=$( cat /proc/cpuinfo | grep -c bogomips )
ncpushares=$(( 1024 / $ncpus ))

mem_bytes=$( free -b | head -n2 | tail -n1 | awk '{print $2}' )
mem_share_bytes=$(( $mem_bytes / $ncpus ))

# Fetch the /proc/cpuinfo up to the first blank
while read Line ; do
  if [[ $Line == '' ]] ; then
    break
  else
    echo "$Line"
  fi
done < <( cat /proc/cpuinfo ) > "${prog_dir}/proc-cpuinfo-1cpu"

# Prepare the configuration file
cat "${prog_dir}/condor-configure" |  
  sed -e "s|@CONDOR_SECRET@|$(cat ${prog_dir}/condor-secret)|g" > "${prog_dir}/condor-configure.ok"

# See here[1] for the swap
# https://github.com/docker/docker/blob/master/docs/sources/reference/run.md
echo exec docker run -i -t \
  -v /cvmfs/alice.cern.ch:/cvmfs/alice.cern.ch \
  -v ${prog_dir}/condor-configure:/condor-configure \
  -v ${prog_dir}/condor-hook-job-exit:/condor-hook-job-exit \
  -v ${prog_dir}/proc-cpuinfo-1cpu:/proc/cpuinfo \
  -m 2g \
  --cpu-shares=$ncpushares \
  --memory=$mem_share_bytes \
  --memory-swap=0 \
  --rm \
  pippo "$@"
