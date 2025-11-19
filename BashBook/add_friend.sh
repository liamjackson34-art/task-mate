#!/bin/bash
if [ $# -ne 2 ];then
echo "nok: bad request"
exit 1
fi
id="$1"
friend="$2"

if [ ! -d "$id" ]; then
echo "nok: user'$user' does not exist"
exit 1
fi
if grep -qx "$friend" "$id/friends.txt" 2>/dev/null; then
echo "ok: friend added!"
exit 0
fi
echo "$friend" >> "$id/friends.txt"
echo "ok:friend added!"

