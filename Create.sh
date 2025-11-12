id=$1

if [ -z "$id" ]; then    #Check argument
	echo "nok: no identifier provided"
	exit 1
fi 

if [ -d "$id" ]; then    #Check if user exists
	echo "nok: user already exists"
	exit 1
fi



mkdir "$id" 2>/dev/null
touch "$id/Friends.txt"
mkdir "$id/Wall"

echo "ok: user created!"
exit 0

