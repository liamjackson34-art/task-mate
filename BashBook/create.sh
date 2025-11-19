#!/bin/bash
if [ $# -ne 1 ]; then
echo "nok: no identifier provided"
exit 1
fi
id="$1"

if [ -d "$id" ]; then
echo "nok: user already exists"
exit 1
fi
mkdir "$id" 2>/dev/null
touch "$id/wall.txt" "$id/friends.txt" 2>/dev/null
echo "ok: user created"
