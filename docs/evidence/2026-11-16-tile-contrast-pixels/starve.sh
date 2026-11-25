#!/bin/zsh
# Pause and resume only the Brickson process of one simulator, in a duty cycle.
# usage: starve.sh <udid> <stop seconds> <run seconds> <flag file>
udid=$1; stop=$2; go=$3; flag=$4
while [ -f "$flag" ]; do
  pids=($(pgrep -f "$udid/data/Containers/Bundle/Application/[^/]*/Brickson.app/Brickson"))
  if (( ${#pids} )); then kill -STOP $pids 2>/dev/null; sleep $stop; kill -CONT $pids 2>/dev/null; sleep $go; else sleep 0.05; fi
done
pids=($(pgrep -f "$udid/data/Containers/Bundle/Application/[^/]*/Brickson.app/Brickson")); (( ${#pids} )) && kill -CONT $pids 2>/dev/null
