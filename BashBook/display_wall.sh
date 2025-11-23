#!/bin/bash
# Check if exactly one argument (user id) is provided
if [ $# -ne 1 ]; then
  echo "nok: bad request"
  exit 1 
fi

# Assign the first argument to variable 'id'
id="$1"

# Check if the directory named after 'id' exists (user validation)
if [ ! -d "$id" ]; then
  echo "nok: user '$id' does not exist"
  exit 1
fi

# Output marker indicating the start of the file contents
echo "start_of_file"

# Display the contents of the user's wall.txt file
cat "$id/wall.txt"

# Output marker indicating the end of the file contents
echo "end_of_file"
