#!/bin/bash
if [ $# -lt 3 ]; then
echo "nok: bad request"
exit 1
fi
sender="$1"
receiver="$2"
shift 2
message="$@"

if [ ! -d "$sender" ]; then
echo "nok: user '$sender'does not exist"
exit 1 
fi

if [ ! -d "$receiver" ]; then
echo "nok: user, $receiver' does not exist" 
exit 1 
fi

if ! grep -qx "$sender" "$receiver/friends.txt" 2>/dev/null; then
echo "nok:user '$sender' is not a firned of'$reciever"
exit 1
fi
echo "$sender: $message" >>"$receiver/wall.txt"
echo "ok: message posted"
