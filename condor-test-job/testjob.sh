#!/bin/bash
sleep_s=120
echo "Our system is $(uname -a)."
if [[ $sleep_s -gt 0 ]] ; then
  echo "Now taking a nap for ${sleep_s} seconds..."
  sleep $sleep_s
fi
#echo hello world err >&2
