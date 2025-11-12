id=$1
friendId=$2

if [ ! -d "$id" ]; then
	echo "user id does not exist"
fi

if [ ! -d "$friendId" ]; then
	echo "friend id does not exist"
fi

if ! grep "^$friendId$" "$id/Friends.txt" > /dev/null 2>&1; then
	echo -e "$friendId\n" >> "$id/Friends.txt"
else 
	echo "Friend already in Friends list"
fi


