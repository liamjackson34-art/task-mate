#!/bin/bash
# Infinite loop to keep the server running and accepting commands continuously
while true; do 
  # Display a prompt symbol '>' without a newline for user input
  echo -n "> "
  
  # Read user input into 'cmd' (command) and 'args' (arguments)
  read -r cmd args
  
  # Set positional parameters from command and arguments for easy forwarding
  set -- $cmd $args
  
  # Assign the first positional parameter to 'request' and shift it from the list
  request=$1
  shift
  
  # Handle the command based on the 'request' value
  case "$request" in
    # Executes the create.sh script
    create)
      ./create.sh "$@"
      ;;
    
    # Executes the add_friend.sh script
    add)
      ./add_friend.sh "$@"
      ;;
    
    # Executes the post_message.sh script
    post)
      ./post_message.sh "$@"
      ;;
    
    # Executes the display_wall.sh script 
    display)
      ./display_wall.sh "$@"
      ;;
    
    # returnx an error message
    *)
      echo "nok: bad request"
      ;;
  esac
done
