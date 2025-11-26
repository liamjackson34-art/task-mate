#!/bin/bash

SERVER_PIPE="server.pipe"
LOCK_NAME="global"   # for acquire.sh / release.sh

# Create the server pipe if it doesn't exist
if [ ! -p "$SERVER_PIPE" ]; then
  mkfifo "$SERVER_PIPE"
fi

cleanup() {
  rm -f "$SERVER_PIPE"
  exit 0
}

# Trap Ctrl+C (SIGINT) and TERM to clean up
trap cleanup INT TERM

while true; do
  # Inner loop ends when all writers close the FIFO; outer loop reopens it
  while read -r line; do
    # Ignores empty lines
    [ -z "$line" ] && continue

    # Parse: request id args
    set -- $line
    request="$1"
    id="$2"
    shift 2   # now "$@" are args for the helper scripts 

    # Ensure client pipe exists
    CLIENT_PIPE="$id.pipe"
    if [ ! -p "$CLIENT_PIPE" ]; then
      # Cannot answer this client, ignore the request
      continue
    fi

    case "$request" in
    
# creates commands for users with the lock and release surrounding each write command
      create)
        ./acquire.sh "$LOCK_NAME"
        ./create.sh "$id" > "$CLIENT_PIPE"
        ./release.sh "$LOCK_NAME"
        ;;

      add)
        ./acquire.sh "$LOCK_NAME"
        ./add_friend.sh "$id" "$@" > "$CLIENT_PIPE"
        ./release.sh "$LOCK_NAME"
        ;;

      post)
        ./acquire.sh "$LOCK_NAME"
        ./post_message.sh "$id" "$@" > "$CLIENT_PIPE"
        ./release.sh "$LOCK_NAME"
        ;;

      display)
        ./display_wall.sh "$id" > "$CLIENT_PIPE"
        ;;

      *)
        echo "nok: bad request" > "$CLIENT_PIPE"
        ;;
    esac

  done < "$SERVER_PIPE"
done
