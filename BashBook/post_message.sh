#!/bin/bash
# Check if the script received at least 3 arguments (sender, receiver, message)
if [ $# -lt 3 ]; then
  echo "nok: bad request"
  exit 1
fi

# Assign the first argument to sender and second to receiver
sender="$1"
receiver="$2"
# Shift positional parameters to the left by 2 to get the rest as the message
shift 2

# Combine all remaining arguments into a single message string
message="$@"

# Verify that the sender directory (user) exists
if [ ! -d "$sender" ]; then
  echo "nok: user '$sender' does not exist"
  exit 1 
fi

# Verify that the receiver directory (user) exists
if [ ! -d "$receiver" ]; then
  echo "nok: user '$receiver' does not exist"
  exit 1 
fi

# Check if sender is listed as a friend in receiver's friends.txt (exact match)
if ! grep -qx "$sender" "$receiver/friends.txt" 2>/dev/null; then
  echo "nok: user '$sender' is not a friend of '$receiver'"
  exit 1
fi

# Append the sender and message to the receiver's wall.txt file
echo "$sender: $message" >> "$receiver/wall.txt"

# Confirm that the message was successfully posted
echo "ok: message posted"
