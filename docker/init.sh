#!/bin/bash
  
# turn on bash's job control
set -m
  
# Start the primary process and put it in the background
mopidy &
  
# Start the helper process
snapserver
  
# now we bring the primary process back into the foreground
# and leave it there
fg %1
