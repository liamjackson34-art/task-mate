#!/bin/bash

# Check we got a user id
if [ $# -ne 1 ]; then
  echo "Usage: $0 <user_id>"
  exit 1
fi

id="$1"
CLIENT_PIPE="$id.pipe"
SERVER_PIPE="server.pipe"

# Check that the server pipe exists
if [ ! -p "$SERVER_PIPE" ]; then
  echo "ERROR: server is not running (missing $SERVER_PIPE)"
  exit 1
fi

# Create our private pipe if it doesn't exist
if [ ! -p "$CLIENT_PIPE" ]; then
  mkfifo "$CLIENT_PIPE"
fi

cleanup() {
  rm -f "$CLIENT_PIPE"
  exit 0
}

# Trap Ctrl+C (SIGINT)
trap cleanup INT

while true; do
  echo -n "> "
  if ! read -r line; then
    # EOF (Ctrl+D), clean up and exit
    cleanup
  fi

  # Ignore empty input
  [ -z "$line" ] && continue

  # Parse first token as request
  set -- $line
  request="$1"
  shift
  args=("$@")

  case "$request" in
    create)
      # client sends: create <id>
      server_msg="create $id"
      ;;

    add)
      if [ ${#args[@]} -ne 1 ]; then
        echo "ERROR: usage: add <friend_id>"
        continue
      fi
      friend="${args[0]}"
      # server receives: add id friend
      server_msg="add $id $friend"
      ;;

    post)
      if [ ${#args[@]} -lt 2 ]; then
        echo "ERROR: usage: post <friend_id> <message...>"
        continue
      fi
      receiver="${args[0]}"
      # rest is message
      unset 'args[0]'
      message="${args[*]}"
      # server receives: post id receiver message...
      server_msg="post $id $receiver $message"
      ;;

    display)
      # server receives: display id
      server_msg="display $id"
      ;;

    *)
      echo "ERROR: unknown command"
      continue
      ;;
  esac

  # Send request to server
  echo "$server_msg" > "$SERVER_PIPE"

  # Now read and display the response

  if [ "$request" = "display" ]; then
    # First line can either be an error (nok: ...) or "start_of_file"
    if ! read -r first_line < "$CLIENT_PIPE"; then
      echo "ERROR: no response from server"
      continue
    fi

    case "$first_line" in
      nok:*)
        msg="${first_line#nok:}"
        echo "ERROR:$msg"
        ;;
      start_of_file)
        # Read until end_of_file
        while read -r line < "$CLIENT_PIPE"; do
          [ "$line" = "end_of_file" ] && break
          echo "$line"
        done
        ;;
      *)
        # Unexpected, just print it
        echo "$first_line"
        ;;
    esac

  else
    # Single-line response expected
    if ! read -r response < "$CLIENT_PIPE"; then
      echo "ERROR: no response from server"
      continue
    fi

    case "$response" in
      ok:*)
        msg="${response#ok:}"
        echo "SUCCESS:$msg"
        ;;
      nok:*)
        msg="${response#nok:}"
        echo "ERROR:$msg"
        ;;
      *)
        # Shouldn't normally happen, but show it raw
        echo "$response"
        ;;
    esac
  fi

done
