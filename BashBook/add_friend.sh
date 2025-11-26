#!/bin/bash

# Expect exactly 2 arguments: user and friend
if [ $# -ne 2 ]; then
  echo "nok: bad request"
  exit 1
fi

user="$1"
friend="$2"

# Prevent adding yourself
if [ "$user" = "$friend" ]; then
  echo "nok: cannot add yourself as a friend"
  exit 1
fi

# Check both users exist
if [ ! -d "$user" ]; then
  echo "nok: user '$user' does not exist"
  exit 1
fi

if [ ! -d "$friend" ]; then
  echo "nok: user '$friend' does not exist"
  exit 1
fi

user_friends="$user/friends.txt"
friend_friends="$friend/friends.txt"

# Make sure the files exist (should already from create.sh, but just in case)
touch "$user_friends" "$friend_friends" 2>/dev/null

# Check if they are already mutual friends
if grep -qx "$friend" "$user_friends" 2>/dev/null && \
   grep -qx "$user"  "$friend_friends" 2>/dev/null; then
  echo "nok: users '$user' and '$friend' are already friends"
  exit 1
fi

# Add friend to user's list if not already there
if ! grep -qx "$friend" "$user_friends" 2>/dev/null; then
  echo "$friend" >> "$user_friends"
fi

# Add user to friend's list if not already there
if ! grep -qx "$user" "$friend_friends" 2>/dev/null; then
  echo "$user" >> "$friend_friends"
fi

echo "ok: friends added"
