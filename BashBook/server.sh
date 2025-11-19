#!/bin/bash
while true; do #loop to keep server going
echo -n"> " #user prompt for input in terminal
read -r cmd args #reads command from user and its arguments
set -- $cmd $args
request=$1
shift
case "$request" in
create)
./create.sh "$@";;
add)
./add_friend.sh "$@";;
post)
./post_message.sh "$@";;
display)
./display_wall.sh "$@";;
*)
echo "nok: bad request";;
esac
done
