#!/bin/bash
if [ $# -ne 2 ];then # Check if the number of arguments passed is exactly 2
echo "nok: bad request"
exit 1
fi
if [ ! -d "$id" ]; then # Assign first argument to variable id and second to frien
id="$1" 
friend="$2"
# Check if a directory named after the id exists
echo "nok: user'$user' does not exist"
exit 1
fi
if grep -qx "$friend" "$id/friends.txt" 2>/dev/null; then
echo "ok: friend added!"
exit 0
fi
echo "$friend" >> "$id/friends.txt" # Append friend to the friends.txt file for the use
echo "ok:friend added!"

