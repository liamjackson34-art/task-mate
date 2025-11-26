#!/bin/bash
lock="lock_$1"

# spin until we can create the lock directory
while ! mkdir "$lock" 2>/dev/null; do
  sleep 0.1
done
