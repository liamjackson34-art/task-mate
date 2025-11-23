#!/bin/bash
# Check that exactly one argument (the user identifier) is provided
if [ $# -ne 1 ]; then
  echo "nok: no identifier provided"
  exit 1
fi

# Store the provided identifier in the variable 'id'
id="$1"

# Check if a directory with this id already exists (user already created)
if [ -d "$id" ]; then
  echo "nok: user already exists"
  exit 1
fi

# Create a directory for the new user, suppressing error messages if any
mkdir "$id" 2>/dev/null

# Create empty 'wall' and 'friends' files for the user, suppressing error messages
touch "$id/wall.txt" "$id/friends.txt" 2>/dev/null

# Indicate successful user creation
echo "ok: user created"
